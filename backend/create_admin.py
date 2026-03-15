from backend.database import SessionLocal, Base, engine
from backend.models import User
from backend.main import hash_password

# Ensure tables exist
Base.metadata.create_all(bind=engine)

db = SessionLocal()

# Check if admin already exists
existing_admin = db.query(User).filter(User.email == "admin@gmail.com").first()

if not existing_admin:
    admin = User(
        email="admin@gmail.com",
        password_hash=hash_password("admin123")
    )
    db.add(admin)
    db.commit()
    print("✅ Admin user 'admin@gmail.com' created successfully!")
else:
    print("ℹ️ Admin user already exists.")

db.close()