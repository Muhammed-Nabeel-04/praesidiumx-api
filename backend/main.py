import io
import os
import uuid
import threading
import json
from datetime import datetime, timedelta
from typing import Dict, Any, List

import pandas as pd
from fastapi import FastAPI, UploadFile, File, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, EmailStr 
from jose import JWTError, jwt
from passlib.context import CryptContext  

# Database Imports
from sqlalchemy.orm import Session
from backend.database import SessionLocal, engine, Base
from backend.models import AnalysisHistory, User  
from backend.utils.inference import run_inference
from backend.utils.model_info import get_model_info

# Create database tables on startup
Base.metadata.create_all(bind=engine)

app = FastAPI()

# ─── CORS ─────────────────────────────────────────────────────────────────────
# ─── CORS ─────────────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)

# ─── In-memory stores (For Polling Only) ──────────────────────────────────────
jobs:     Dict[str, Any] = {}
jobs_lock = threading.Lock()

# ─── Security & JWT Configuration ─────────────────────────────────────────────
SECRET_KEY = os.getenv("SECRET_KEY", "dev-only-local-key")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 10080

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security = HTTPBearer()

def hash_password(password: str):
    return pwd_context.hash(password)

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    token = credentials.credentials
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            raise HTTPException(status_code=401, detail="Invalid token")
        return email
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

# ─── Dependency: Get Database Session ─────────────────────────────────────────
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# ─── AUTO-SEED ADMIN ON STARTUP ────────────────────────────────────────────
@app.on_event("startup")
def create_default_admin():
    db = SessionLocal()
    admin_email    = os.getenv("ADMIN_EMAIL",    "admin@gmail.com")
    admin_password = os.getenv("ADMIN_PASSWORD", "admin123")
    try:
        if not db.query(User).filter(User.email == admin_email).first():
            db.add(User(
                email=admin_email,
                password_hash=hash_password(admin_password)
            ))
            db.commit()
            print("✅ Admin created.")
    finally:
        db.close()

# ─── Health ───────────────────────────────────────────────────────────────────
@app.get("/health")
def health_check():
    return {"status": "ok", "model_loaded": True}

# ─── Pydantic models (NOW USING EmailStr) ─────────────────────────────────────
class LoginRequest(BaseModel):
    email: EmailStr # Validates email automatically
    password: str

class RegisterRequest(BaseModel):
    email: EmailStr # Validates email automatically
    password: str

# ─── Auth (NOW SECURED WITH DB) ───────────────────────────────────────────────
@app.post("/register")
def register(data: RegisterRequest, db: Session = Depends(get_db)):
    existing_user = db.query(User).filter(User.email == data.email).first()

    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered")

    if len(data.password) < 6:
        raise HTTPException(status_code=400, detail="Password too short")

    

    # Save user permanently to SQL with hashed password
    user = User(
        email=data.email,
        password_hash=hash_password(data.password)
    )

    db.add(user)
    db.commit()

    return {"message": "Account created successfully"}

@app.post("/login")
def login(data: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == data.email).first()

    if not user:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    # Verify hash against plain text input
    if not verify_password(data.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    token = create_access_token({"sub": user.email})

    return {
        "access_token": token,
        "token_type": "bearer"
    }
@app.get("/model-info")
def model_info(user_email: str = Depends(verify_token)):
    return get_model_info()
# ─── Background inference runner (Saves to SQL) ───────────────────────────────
def _run_job(job_id: str, file_bytes: bytes, filename: str, user_email: str):
    try:
        df     = pd.read_csv(io.BytesIO(file_bytes))
        result = run_inference(df)
        
        db = SessionLocal()
        try:
            record = AnalysisHistory(
                job_id=job_id,
                user_email=user_email,
                dataset_name=filename,
                attacks=result["attacks"],
                benign=result["benign"],
                anomalies=result["anomalies"],
                top_ports=json.dumps(result["top_ports"]), 
                full_result=json.dumps(result)             
            )
            db.add(record)
            db.commit()
        finally:
            db.close()

        with jobs_lock:
            jobs[job_id] = {"status": "done", "result": result}
            
        print(f"  Job {job_id[:8]} completed and saved to SQL Database for {user_email}.", flush=True)
    except Exception as e:
        with jobs_lock:
            jobs[job_id] = {"status": "error", "error": str(e)}
        print(f"  Job {job_id[:8]} FAILED: {e}", flush=True)

# ─── POST /analyze — returns job_id immediately ───────────────────────────────
@app.post("/analyze")
async def analyze_csv(
    file: UploadFile = File(...),
    user_email: str = Depends(verify_token),
):
    job_id     = str(uuid.uuid4())
    file_bytes = await file.read()

    with jobs_lock:
        jobs[job_id] = {"status": "processing"}

    thread = threading.Thread(
        target=_run_job,
        args=(job_id, file_bytes, file.filename, user_email),
        daemon=True,
    )
    thread.start()
    print(f"▶ Job {job_id[:8]} started by {user_email}.", flush=True)

    return {"job_id": job_id, "status": "processing"}

# ─── GET /status/{job_id} — poll for result ───────────────────────────────────
@app.get("/status/{job_id}")
def get_status(
    job_id: str,
    user_email: str = Depends(verify_token),
):
    with jobs_lock:
        job = jobs.get(job_id)

    if job is None:
        raise HTTPException(status_code=404, detail="Job not found")

    return job

# ─── GET /history — fetch user's past SQL analyses ────────────────────────────
@app.get("/history")
def get_history(
    db: Session = Depends(get_db),
    user_email: str = Depends(verify_token)
):
    records = db.query(AnalysisHistory)\
        .filter(AnalysisHistory.user_email == user_email)\
        .order_by(AnalysisHistory.created_at.desc())\
        .all()

    return [
        {
            "id": r.id,
            "job_id": r.job_id,
            "dataset_name": r.dataset_name,
            "attacks": r.attacks,
            "benign": r.benign,
            "anomalies": r.anomalies,
            "created_at": r.created_at.isoformat(),
            "top_ports": json.loads(r.top_ports),
            "full_result": json.loads(r.full_result)
        }
        for r in records
    ]

# ─── DELETE /history/{job_id} — Delete from SQL ───────────────────────────────
@app.delete("/history/{job_id}")
def delete_history(
    job_id: str,
    db: Session = Depends(get_db),
    user_email: str = Depends(verify_token)
):
    record = db.query(AnalysisHistory).filter(
        AnalysisHistory.job_id == job_id,
        AnalysisHistory.user_email == user_email 
    ).first()
    
    if not record:
        raise HTTPException(status_code=404, detail="Record not found or unauthorized")

    db.delete(record)
    db.commit()

    return {"status": "success", "message": "Record deleted"}