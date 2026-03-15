from sqlalchemy import Column, Integer, String, DateTime
from backend.database import Base
from datetime import datetime

# ─── New User Table ──────────────────────────────────────
class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    password_hash = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)

# ─── Existing History Table ──────────────────────────────
class AnalysisHistory(Base):
    __tablename__ = "analysis_history"

    id = Column(Integer, primary_key=True, index=True)
    job_id = Column(String, unique=True, index=True) 
    user_email = Column(String, index=True)
    dataset_name = Column(String)
    attacks = Column(Integer)
    benign = Column(Integer)
    anomalies = Column(Integer)
    top_ports = Column(String) 
    full_result = Column(String) 
    created_at = Column(DateTime, default=datetime.utcnow)