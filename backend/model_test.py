import joblib
import torch
import torch.nn as nn
import pandas as pd
import numpy as np

from sklearn.metrics import classification_report, accuracy_score

print("\n================================================")
print("        CYBER ATTACK DETECTION MODEL REPORT")
print("================================================")

# -------------------------------------------------
# LOAD RANDOM FOREST
# -------------------------------------------------

rf = joblib.load("backend/models/random_forest_reetrained.pkl")
scaler = joblib.load("backend/models/autoencoder_scaler.pkl")

print("\n==============================")
print(" RANDOM FOREST MODEL DETAILS")
print("==============================")

print("Number of Trees:", rf.n_estimators)
print("Max Depth:", rf.max_depth)
print("Number of Features:", rf.n_features_in_)
print("Classes:", list(rf.classes_))
print("Criterion:", rf.criterion)
print("Bootstrap:", rf.bootstrap)

# -------------------------------------------------
# LOAD TEST DATA
# -------------------------------------------------

df = pd.read_csv("data/processed/X_test.csv")

if "Label" in df.columns:
    X = df.drop(columns=["Label"])
    y = df["Label"]
else:
    X = df
    y = None

X_scaled = scaler.transform(X)

# -------------------------------------------------
# RANDOM FOREST PERFORMANCE
# -------------------------------------------------

if y is not None:

    y_pred = rf.predict(X_scaled)

    print("\n==============================")
    print(" RANDOM FOREST PERFORMANCE")
    print("==============================")

    print("Accuracy:", accuracy_score(y, y_pred))

    print("\nClassification Report\n")
    print(classification_report(y, y_pred))

# -------------------------------------------------
# AUTOENCODER MODEL
# -------------------------------------------------

class Autoencoder(nn.Module):

    def __init__(self, input_dim=78):
        super(Autoencoder, self).__init__()

        self.encoder = nn.Sequential(
            nn.Linear(input_dim, 64),
            nn.ReLU(),
            nn.Linear(64, 32),
            nn.ReLU()
        )

        self.decoder = nn.Sequential(
            nn.Linear(32, 64),
            nn.ReLU(),
            nn.Linear(64, input_dim)
        )

    def forward(self, x):
        encoded = self.encoder(x)
        decoded = self.decoder(encoded)
        return decoded


print("\n==============================")
print(" AUTOENCODER MODEL DETAILS")
print("==============================")

auto_model = Autoencoder(input_dim=78)

auto_model.load_state_dict(
    torch.load("backend/models/autoencoder_model.pth", map_location="cpu")
)

auto_model.eval()

print(auto_model)

# PARAMETERS

total_params = sum(p.numel() for p in auto_model.parameters())
trainable_params = sum(p.numel() for p in auto_model.parameters() if p.requires_grad)

print("\nTotal Parameters:", total_params)
print("Trainable Parameters:", trainable_params)

# -------------------------------------------------
# AUTOENCODER ANOMALY DETECTION
# -------------------------------------------------

print("\n==============================")
print(" AUTOENCODER ANOMALY TEST")
print("==============================")

X_tensor = torch.tensor(X_scaled, dtype=torch.float32)

with torch.no_grad():
    reconstructed = auto_model(X_tensor)

mse = torch.mean((X_tensor - reconstructed) ** 2, dim=1)

threshold = np.percentile(mse.numpy(), 95)

pred = (mse > threshold).int()

print("Anomaly Threshold:", threshold)
print("Detected Anomalies:", pred.sum().item())

# -------------------------------------------------
# VARIATIONAL AUTOENCODER (VAE)
# -------------------------------------------------

class VAE(nn.Module):
    def __init__(self, input_dim, latent_dim=16):
        super(VAE, self).__init__()

        # Encoder
        self.encoder = nn.Sequential(
            nn.Linear(input_dim, 64),
            nn.ReLU(),
            nn.Linear(64, 32),
            nn.ReLU()
        )

        # Latent space
        self.fc_mu = nn.Linear(32, latent_dim)
        self.fc_logvar = nn.Linear(32, latent_dim)

        # Decoder
        self.decoder = nn.Sequential(
            nn.Linear(latent_dim, 32),
            nn.ReLU(),
            nn.Linear(32, 64),
            nn.ReLU(),
            nn.Linear(64, input_dim)
        )

    def reparameterize(self, mu, logvar):
        std = torch.exp(0.5 * logvar)
        eps = torch.randn_like(std)
        return mu + eps * std

    def forward(self, x):
        encoded = self.encoder(x)
        mu = self.fc_mu(encoded)
        logvar = self.fc_logvar(encoded)
        z = self.reparameterize(mu, logvar)
        decoded = self.decoder(z)
        return decoded, mu, logvar

print("\n==============================")
print(" VARIATIONAL AUTOENCODER")
print("==============================")

vae = VAE(input_dim=78)

try:

    vae.load_state_dict(
        torch.load("backend/models/vAutoEncoder_model.pth", map_location="cpu")
    )

    vae.eval()

    print(vae)

    params = sum(p.numel() for p in vae.parameters())

    print("\nTotal Parameters:", params)

except Exception as e:
    print("VAE loading failed:")
    print(e)

print("\n================================================")
print(" REPORT COMPLETE")
print("================================================")