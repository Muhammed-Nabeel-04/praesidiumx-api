import torch
import torch.nn as nn

# -----------------------------
# STEP 4.2: AUTOENCODER MODEL
# -----------------------------

class Autoencoder(nn.Module):
    def __init__(self, input_dim):
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


# -----------------------------
# Test the model
# -----------------------------
if __name__ == "__main__":
    input_dim = 78
    model = Autoencoder(input_dim)

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = model.to(device)

    print("Autoencoder model created")
    print("Using device:", device)
    print(model)
