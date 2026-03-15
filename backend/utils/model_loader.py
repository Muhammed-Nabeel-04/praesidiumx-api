import joblib
import torch
# ✅ NEW
from backend.utils.step4_2_autoencoder_model import Autoencoder


def load_models():
    rf = joblib.load("backend/models/random_forest_reetrained.pkl")
    scaler = joblib.load("backend/models/autoencoder_scaler.pkl")

    ae = Autoencoder(input_dim=len(rf.feature_names_in_))
    ae.load_state_dict(torch.load("backend/models/autoencoder_model.pth", map_location="cpu"))
    ae.eval()

    return rf, ae, scaler
