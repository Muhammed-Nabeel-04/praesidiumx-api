# PraesidiumX 🛡️
### AI-Powered Cybersecurity Threat Intelligence Platform

> Upload network traffic → Get instant AI analysis → Understand exactly WHY each flow was flagged

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat&logo=flutter)
![FastAPI](https://img.shields.io/badge/FastAPI-0.104-009688?style=flat&logo=fastapi)
![Python](https://img.shields.io/badge/Python-3.10+-3776AB?style=flat&logo=python)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Web%20%7C%20Windows-brightgreen?style=flat)

---

## What is PraesidiumX?

PraesidiumX is a full-stack cybersecurity platform that takes raw network traffic CSV files and runs them through a trained Machine Learning pipeline to detect attacks, identify anomalies, and explain predictions using SHAP values — all through a polished mobile and web app.

Built as a Final Year Project demonstrating the integration of:
- **Explainable AI (XAI)** for cybersecurity
- **Cross-platform Flutter** development
- **Production-grade FastAPI** backend
- **Real ML models** trained on CICIDS2017 benchmark dataset

---

## Features

- 🔍 **Attack Detection** — Random Forest classifier identifies DDoS, Port Scan, Brute Force, and more
- 🧠 **Anomaly Detection** — PyTorch Autoencoder catches unknown/zero-day threats
- 📊 **SHAP Explainability** — Per-flow explanations showing exactly which features triggered each alert
- 📱 **Cross-Platform** — Same codebase runs on Android, Web, and Windows
- 🔐 **JWT Authentication** — Secure user accounts with 24-hour token expiry
- 📜 **Analysis History** — Full audit log of all past analyses per user
- ⚙️ **Smart URL Config** — Automatic environment detection (emulator / device / production)

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile / Web App | Flutter 3.x (Dart) |
| Backend API | FastAPI (Python) |
| ML Classification | scikit-learn — Random Forest |
| Anomaly Detection | PyTorch — Autoencoder |
| Explainability | SHAP — TreeExplainer |
| Database | SQLite (dev) / PostgreSQL (prod) |
| Authentication | JWT (python-jose) + bcrypt |
| Training Dataset | CICIDS2017 |

---

## Project Structure

```
cyber_project/
├── backend/
│   ├── main.py               ← FastAPI app — all endpoints
│   ├── models.py             ← SQLAlchemy ORM models
│   ├── database.py           ← DB engine + session
│   └── utils/
│       └── inference.py      ← ML pipeline + SHAP + anomaly detection
│
├── frontend/security_app/
│   ├── lib/
│   │   ├── main.dart         ← App entry point
│   │   ├── services/
│   │   │   ├── api_config.dart    ← Multi-environment URL management
│   │   │   ├── api_service.dart   ← HTTP client
│   │   │   └── auth_service.dart  ← Auth + token management
│   │   ├── screens/
│   │   │   ├── splash_screen.dart
│   │   │   ├── login_screen.dart
│   │   │   ├── home_screen.dart
│   │   │   ├── dashboard_screen.dart
│   │   │   ├── history_screen.dart
│   │   │   └── settings_screen.dart
│   │   └── theme/
│   │       └── app_colors.dart    ← Centralized design system
│   └── assets/
│       └── inside_logo.png   ← App logo
│
├── Procfile                  ← Railway deployment
├── railway.json              ← Railway config
├── requirements.txt          ← Python dependencies
└── README.md
```

---

## Getting Started

### Prerequisites

- Python 3.10+
- Flutter 3.x
- Node.js (optional, for web)

---

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/praesidiumx.git
cd praesidiumx
```

---

### 2. Run the Backend

```bash
# Install dependencies
pip install -r requirements.txt

# Start the server
uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload
```

Visit `http://localhost:8000/docs` to see the interactive API documentation.

---

### 3. Run the Flutter App

```bash
cd frontend/security_app

# Install Flutter dependencies
flutter pub get

# Run on Android emulator
flutter run

# Run on web
flutter run -d chrome

# Build release APK
flutter build apk --release
```

---

### 4. Configure Backend URL

When running on a **physical Android device**, open the app and:

1. Tap the ⚙️ Settings icon on the login screen
2. Enter your PC's IP address: `http://192.168.X.X:8000`
3. Find your IP with `ipconfig` (Windows) or `ifconfig` (Mac/Linux)
4. Tap **SAVE & APPLY**

> ℹ️ Your phone and PC must be on the same WiFi network.

| Environment | URL to use |
|---|---|
| Android Emulator | `http://10.0.2.2:8000` (auto-detected) |
| Physical Device | `http://YOUR_PC_IP:8000` |
| Web Browser | `http://localhost:8000` (auto-detected) |
| Production | Set in `api_config.dart` as `_productionUrl` |

---

## API Endpoints

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| GET | `/health` | No | Server status + model loaded check |
| POST | `/register` | No | Create new user account |
| POST | `/login` | No | Login, returns JWT token |
| POST | `/analyze` | JWT | Upload CSV, returns job_id |
| GET | `/status/{job_id}` | JWT | Poll analysis progress |
| GET | `/history` | JWT | Get all past analyses |
| DELETE | `/history/{job_id}` | JWT | Delete a history record |

---

## ML Pipeline

```
CSV Upload
    │
    ▼
Feature Engineering (78 features, fill NaN, clip inf)
    │
    ▼
StandardScaler Normalization
    │
    ├──► Random Forest Classifier ──► Attack / Benign label per flow
    │
    ├──► Autoencoder (PyTorch) ──► Reconstruction error > threshold = Anomaly
    │
    └──► SHAP TreeExplainer ──► Feature importance per attack flow
    │
    ▼
Result: { attacks, benign, anomalies, top_ports, flow_details, shap_values, timeline }
```

The model was trained on the **CICIDS2017** dataset — 2.8 million labeled network flows captured over 5 days in a realistic lab environment, containing DDoS, PortScan, BruteForce, Infiltration, WebAttack, DoS, and Heartbleed attack types.

---

## Environment Variables

Copy `.env.example` to `.env` and fill in:

```env
SECRET_KEY=your-random-32-byte-hex-key
ENVIRONMENT=development
FRONTEND_URL=http://localhost:5000
TOKEN_EXPIRE_MINUTES=1440
ADMIN_EMAIL=admin@example.com
ADMIN_PASSWORD=change-this
```

Generate a secure key with:
```bash
python -c "import secrets; print(secrets.token_hex(32))"
```

---

## Deployment

### Backend → Railway.app

```bash
npm install -g @railway/cli
railway login
railway init
railway up
```

Add a **PostgreSQL plugin** in the Railway dashboard — `DATABASE_URL` is set automatically.

### Frontend (Web) → Netlify

```bash
flutter build web --release
# Drag build/web/ folder to netlify.com
```

### Android → Release APK

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## Screenshots

> _Add screenshots here after deployment_

| Login | Home | Dashboard |
|---|---|---|
| ![login](docs/login.png) | ![home](docs/home.png) | ![dashboard](docs/dashboard.png) |

---

## Platform Support

| Platform | Status | Command |
|---|---|---|
| Android | ✅ Ready | `flutter build apk --release` |
| Web | ✅ Ready | `flutter build web --release` |
| Windows | ✅ Ready | `flutter build windows --release` |
| iOS | ⚠️ Needs Mac | `flutter build ipa` (on Mac) |
| macOS | ⚠️ Needs Mac | `flutter build macos` (on Mac) |
| Linux | 🔧 Possible | `flutter build linux --release` |

---

## License

This project was developed as a Final Year academic project.  
© 2025 Muhammed Nabeel. All rights reserved.

---

<p align="center">Built with Flutter + FastAPI + ❤️</p>
