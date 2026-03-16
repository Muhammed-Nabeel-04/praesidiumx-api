import joblib
import torch
import torch.nn as nn
import numpy as np
import pandas as pd
import os

# ─── Model Definitions (must match training code) ─────────────────────────────

class Autoencoder(nn.Module):
    def __init__(self, input_dim=78):
        super().__init__()
        self.encoder = nn.Sequential(
            nn.Linear(input_dim, 64), nn.ReLU(),
            nn.Linear(64, 32),        nn.ReLU()
        )
        self.decoder = nn.Sequential(
            nn.Linear(32, 64), nn.ReLU(),
            nn.Linear(64, input_dim)
        )
    def forward(self, x):
        return self.decoder(self.encoder(x))


class VAE(nn.Module):
    def __init__(self, input_dim=78, latent_dim=16):
        super().__init__()
        self.encoder = nn.Sequential(
            nn.Linear(input_dim, 64), nn.ReLU(),
            nn.Linear(64, 32),        nn.ReLU()
        )
        self.fc_mu     = nn.Linear(32, latent_dim)
        self.fc_logvar = nn.Linear(32, latent_dim)
        self.decoder = nn.Sequential(
            nn.Linear(latent_dim, 32), nn.ReLU(),
            nn.Linear(32, 64),         nn.ReLU(),
            nn.Linear(64, input_dim)
        )
    def reparameterize(self, mu, logvar):
        std = torch.exp(0.5 * logvar)
        return mu + torch.randn_like(std) * std
    def forward(self, x):
        enc    = self.encoder(x)
        mu     = self.fc_mu(enc)
        logvar = self.fc_logvar(enc)
        z      = self.reparameterize(mu, logvar)
        return self.decoder(z), mu, logvar


# ─── Main function called by the endpoint ─────────────────────────────────────

def get_model_info() -> dict:
    base = "backend/models"

    # ── Random Forest ──────────────────────────────────────────────────────────
    rf      = joblib.load(f"{base}/random_forest_reetrained.pkl")
    scaler  = joblib.load(f"{base}/autoencoder_scaler.pkl")

    rf_info = {
        "n_estimators":   rf.n_estimators,
        "max_depth":      str(rf.max_depth),          # None → string
        "n_features":     rf.n_features_in_,
        "classes":        list(map(int, rf.classes_)),
        "criterion":      rf.criterion,
        "bootstrap":      rf.bootstrap,
        "max_features":   "sqrt(78) ≈ 9",
        "accuracy":       None,
        "f1_attack":      None,
        "precision":      None,
        "recall":         None,
        "benign_p":       None,
        "benign_r":       None,
        "benign_f1":      None,
        "attack_p":       None,
        "attack_r":       None,
        "attack_f1":      None,
    }

    # Try to compute real metrics if labeled test data exists
    test_path = "data/processed/X_test.csv"
    if os.path.exists(test_path):
        try:
            from sklearn.metrics import (
                accuracy_score, precision_score,
                recall_score, f1_score, classification_report
            )
            df        = pd.read_csv(test_path)
            label_col = next((c for c in df.columns if c.strip().lower() == "label"), None)

            if label_col:
                X = df.drop(columns=[label_col])
                y = df[label_col]
            else:
                # Try separate label files
                y_candidates = [
                    "data/processed/y_test.csv",
                    "data/processed/y_test.npy",
                    "data/processed/labels_test.csv",
                ]
                y = None
                for yp in y_candidates:
                    if os.path.exists(yp):
                        y = pd.read_csv(yp).iloc[:, 0] if yp.endswith(".csv") \
                            else pd.Series(np.load(yp))
                        print(f"RF metrics: loaded labels from {yp}")
                        break
                if y is None:
                    print(f"RF metrics skipped: no Label column and no y_test file found.")
                    raise ValueError("No label column")
                X = df

            # Align columns to match training feature order
            if hasattr(rf, 'feature_names_in_'):
                X = X[rf.feature_names_in_]

            # Encode string labels -> 0/1 if needed
            if y.dtype == object:
                y = y.str.strip().map(lambda v: 0 if str(v).upper() == 'BENIGN' else 1)
            y = y.astype(int)

            # RF was trained on RAW features — do NOT scale before predicting
            y_pred = rf.predict(X)

            report = classification_report(y, y_pred, output_dict=True, zero_division=0)
            classes = sorted(y.unique())
            c0 = str(classes[0])
            c1 = str(classes[1])

            rf_info.update({
                "accuracy":   round(accuracy_score(y, y_pred) * 100, 2),
                "f1_attack":  round(f1_score(y, y_pred, pos_label=1, zero_division=0) * 100, 2),
                "precision":  round(precision_score(y, y_pred, pos_label=1, zero_division=0) * 100, 2),
                "recall":     round(recall_score(y, y_pred, pos_label=1, zero_division=0) * 100, 2),
                "benign_p":   round(report[c0]["precision"] * 100, 1),
                "benign_r":   round(report[c0]["recall"] * 100, 1),
                "benign_f1":  round(report[c0]["f1-score"] * 100, 1),
                "attack_p":   round(report[c1]["precision"] * 100, 1),
                "attack_r":   round(report[c1]["recall"] * 100, 1),
                "attack_f1":  round(report[c1]["f1-score"] * 100, 1),
            })
            print(f"RF metrics OK. Accuracy: {rf_info['accuracy']}%")
        except Exception as e:
            print(f"RF metrics skipped: {e}")

    # ── Autoencoder ────────────────────────────────────────────────────────────
    ae = Autoencoder(input_dim=78)
    ae.load_state_dict(
        torch.load(f"{base}/autoencoder_model.pth", map_location="cpu")
    )
    ae.eval()
    ae_params = sum(p.numel() for p in ae.parameters())

    # Recompute threshold from test data if available
    ae_threshold       = 0.8802276492118805   # fallback from model_test.py
    ae_anomalies_found = 2231

    if os.path.exists(test_path):
        try:
            df        = pd.read_csv(test_path)
            label_col = next((c for c in df.columns if c.strip().lower() == "label"), None)
            X         = df.drop(columns=[label_col]) if label_col else df
            Xs  = scaler.transform(X)
            Xt  = torch.tensor(Xs, dtype=torch.float32)
            with torch.no_grad():
                recon = ae(Xt)
            mse = torch.mean((Xt - recon) ** 2, dim=1).numpy()
            ae_threshold       = float(np.percentile(mse, 95))
            ae_anomalies_found = int((mse > ae_threshold).sum())
        except Exception as e:
            print(f"AE threshold recompute skipped: {e}")

    ae_info = {
        "input_dim":        78,
        "encoder_dims":     [64, 32],
        "latent_dim":       32,
        "decoder_dims":     [64, 78],
        "total_params":     ae_params,
        "loss":             "MSE",
        "optimizer":        "Adam (lr=0.001)",
        "threshold":        round(ae_threshold, 6),
        "anomalies_found":  ae_anomalies_found,
        "param_breakdown": {
            "enc_78_64": 78 * 64 + 64,
            "enc_64_32": 64 * 32 + 32,
            "dec_32_64": 32 * 64 + 64,
            "dec_64_78": 64 * 78 + 78,
        },
    }

    # ── VAE ────────────────────────────────────────────────────────────────────
    vae = VAE(input_dim=78, latent_dim=16)
    vae.load_state_dict(
        torch.load(f"{base}/vAutoEncoder_model.pth", map_location="cpu")
    )
    vae.eval()
    vae_params = sum(p.numel() for p in vae.parameters())

    vae_info = {
        "input_dim":    78,
        "encoder_dims": [64, 32],
        "latent_dim":   16,
        "fc_mu_dim":    16,
        "fc_logvar_dim":16,
        "decoder_dims": [32, 64, 78],
        "total_params": vae_params,
        "loss":         "MSE + KL Divergence",
        "param_breakdown": {
            "enc_78_64":    78 * 64 + 64,
            "enc_64_32":    64 * 32 + 32,
            "fc_mu_32_16":  32 * 16 + 16,
            "fc_lv_32_16":  32 * 16 + 16,
            "dec_16_32":    16 * 32 + 32,
            "dec_32_64":    32 * 64 + 64,
            "dec_64_78":    64 * 78 + 78,
        },
    }

    return {
        "random_forest":  rf_info,
        "autoencoder":    ae_info,
        "vae":            vae_info,
    }