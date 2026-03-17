import numpy as np
import pandas as pd
import torch
import shap
from backend.utils.model_loader import load_models

rf, ae, scaler = load_models()
EXPECTED_FEATURES = list(rf.feature_names_in_)


# ─────────────────────────────────────────────────────────────────────────────
def align_features(df, expected_features):
    df = df.copy()
    df.columns = df.columns.str.strip()          
    df = df[[c for c in df.columns if c in expected_features]]
    for col in expected_features:
        if col not in df.columns:
            df[col] = 0.0
    df = df[expected_features]
    df.replace([np.inf, -np.inf], np.nan, inplace=True)
    df = df.apply(pd.to_numeric, errors="coerce")
    df.fillna(0, inplace=True)
    df = df.clip(-1e10, 1e10)
    return df


def clean_dataframe(df):
    return align_features(df, EXPECTED_FEATURES)


# ─────────────────────────────────────────────────────────────────────────────
def run_inference(df):
    print("▶ Starting inference...", flush=True)

    # ── Strip column spaces ────────────────────────────────────────────────
    df.columns = df.columns.str.strip()
    original_df = df.copy()
    print(f"  CSV shape: {df.shape}", flush=True)

    # ── Align features ────────────────────────────────────────────────────
    X = align_features(df, EXPECTED_FEATURES)
    matched = sum(1 for c in EXPECTED_FEATURES if c in df.columns)
    print(f"  Matched features: {matched}/{len(EXPECTED_FEATURES)}", flush=True)

    # ── Random Forest predictions ─────────────────────────────────────────
    rf_preds = rf.predict(X)
    attack_count = int((rf_preds == 1).sum())
    benign_count = int((rf_preds == 0).sum())
    print(f"  Attacks: {attack_count}  Benign: {benign_count}", flush=True)

    # ── Autoencoder anomaly scores ────────────────────────────────────────
    scaled = scaler.transform(X)
    tensor = torch.tensor(scaled, dtype=torch.float32)
    with torch.no_grad():
        recon = ae(tensor)
        error = torch.mean((tensor - recon) ** 2, dim=1).numpy()

    threshold     = np.percentile(error, 95)
    anomaly_count = int((error > threshold).sum())
    print(f"  Anomalies: {anomaly_count}", flush=True)

    # ── Attach predictions & scores to original df ────────────────────────
    original_df["_RF_Pred"]  = rf_preds
    original_df["_AnoScore"] = error

    # ── Top ports ─────────────────────────────────────────────────────────
    if "Destination Port" in original_df.columns:
        attack_rows = original_df[original_df["_RF_Pred"] == 1]
        src         = attack_rows if len(attack_rows) > 0 else original_df
        top_ports   = {
            str(int(k)): int(v)
            for k, v in src["Destination Port"].value_counts().head(5).items()
        }
    else:
        top_ports   = {}
        attack_rows = original_df[original_df["_RF_Pred"] == 1]

    # ── Anomaly score timeline (60 buckets) ───────────────────────────────
    n_buckets   = 60
    bucket_size = max(1, len(error) // n_buckets)
    anomaly_series = [
        round(float(np.mean(error[i: i + bucket_size])), 6)
        for i in range(0, len(error), bucket_size)
    ][:n_buckets]

    # ── SHAP per-flow explainability ──────────────────────────────────────
    print("▶ Computing SHAP values...", flush=True)
    explainer = shap.TreeExplainer(rf)

    attack_idx = np.where(rf_preds == 1)[0]
    benign_idx = np.where(rf_preds == 0)[0]

    rng = np.random.RandomState(42)

    n_atk = min(300, len(attack_idx))
    n_ben = min(100, len(benign_idx))

    sel_atk = rng.choice(attack_idx, n_atk, replace=False) if n_atk > 0 else np.array([], dtype=int)
    sel_ben = rng.choice(benign_idx, n_ben, replace=False) if n_ben > 0 else np.array([], dtype=int)
    sel_all = np.concatenate([sel_atk, sel_ben]).astype(int)

    X_sample    = X.iloc[sel_all]
    shap_values = explainer(X_sample)

    vals = shap_values.values
    if vals.ndim == 3:          # multi-class RF → take class-1 slice
        vals = vals[:, :, 1]

    # ── Build per-flow JSON ───────────────────────────────────────────────
    flows = []
    for i, idx in enumerate(sel_all):
        row_shap  = vals[i]
        top_idx   = np.argsort(np.abs(row_shap))[::-1][:10]

        shap_dict = {
            EXPECTED_FEATURES[j]: round(float(row_shap[j]), 5)
            for j in top_idx
        }

        flow = {
            "id":            int(idx),
            "prediction":    int(rf_preds[idx]),          # 1=attack 0=benign
            "anomaly_score": round(float(error[idx]), 5),
            "is_anomaly":    bool(error[idx] > threshold),
            "shap_values":   shap_dict,
        }

        if "Destination Port" in original_df.columns:
            try:
                flow["destination_port"] = str(int(original_df["Destination Port"].iloc[idx]))
            except Exception:
                flow["destination_port"] = "?"

        flows.append(flow)

    # Sort: attacks first → then by anomaly score desc
    flows.sort(key=lambda f: (-f["prediction"], -f["anomaly_score"]))
    print(f"▶ Done. {len(flows)} flows with SHAP.", flush=True)

    return {
        "attacks":        attack_count,
        "benign":         benign_count,
        "anomalies":      anomaly_count,
        "top_ports":      top_ports,
        "anomaly_series": anomaly_series,   # 60-point timeline
        "flows":          flows,            # per-flow SHAP list
    }
