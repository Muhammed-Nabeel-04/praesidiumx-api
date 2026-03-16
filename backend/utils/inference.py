import gc
import numpy as np
import pandas as pd
import torch
import shap
from backend.utils.model_loader import load_models

rf, ae, scaler = load_models()
EXPECTED_FEATURES = list(rf.feature_names_in_)

CHUNK_SIZE = 1_000   # rows processed at a time — keeps RAM flat


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
    return df.astype(np.float32)   # float32 saves memory vs float64


def clean_dataframe(df):
    return align_features(df, EXPECTED_FEATURES)


# ─────────────────────────────────────────────────────────────────────────────
def run_inference(df):
    print("▶ Starting inference...", flush=True)

    df.columns = df.columns.str.strip()
    total_rows = len(df)
    print(f"  CSV shape: {df.shape} — processing ALL rows in chunks of {CHUNK_SIZE}", flush=True)

    # Keep only needed columns immediately to free RAM from unused columns
    cols_to_keep = [c for c in df.columns if c.strip() in EXPECTED_FEATURES or c == "Destination Port"]
    df = df[cols_to_keep].reset_index(drop=True)

    # ── Chunked RF + AE predictions on ALL rows ───────────────────────────
    # Each chunk is processed and freed before the next one loads
    all_rf_preds = []
    all_ae_errors = []

    n_chunks = (total_rows + CHUNK_SIZE - 1) // CHUNK_SIZE
    print(f"  Processing {n_chunks} chunks...", flush=True)

    for chunk_idx in range(n_chunks):
        start = chunk_idx * CHUNK_SIZE
        end   = min(start + CHUNK_SIZE, total_rows)
        chunk = df.iloc[start:end].copy()

        # Align features for this chunk
        X_chunk = align_features(chunk, EXPECTED_FEATURES)
        del chunk

        # RF prediction
        rf_preds_chunk = rf.predict(X_chunk)
        all_rf_preds.append(rf_preds_chunk)

        # AE anomaly score
        scaled = scaler.transform(X_chunk).astype(np.float32)
        tensor = torch.tensor(scaled, dtype=torch.float32)
        del scaled

        with torch.no_grad():
            recon = ae(tensor)
            error_chunk = torch.mean((tensor - recon) ** 2, dim=1).numpy()
        del tensor, recon
        all_ae_errors.append(error_chunk)

        del X_chunk
        gc.collect()

    # Combine all chunk results
    rf_preds = np.concatenate(all_rf_preds)
    error    = np.concatenate(all_ae_errors)
    del all_rf_preds, all_ae_errors
    gc.collect()

    attack_count  = int((rf_preds == 1).sum())
    benign_count  = int((rf_preds == 0).sum())
    threshold     = np.percentile(error, 95)
    anomaly_count = int((error > threshold).sum())

    print(f"  Attacks: {attack_count}  Benign: {benign_count}  Anomalies: {anomaly_count}", flush=True)

    # ── Attach predictions & scores to original df ────────────────────────
    df["_RF_Pred"]  = rf_preds
    df["_AnoScore"] = error

    # ── Top ports ─────────────────────────────────────────────────────────
    if "Destination Port" in df.columns:
        attack_rows = df[df["_RF_Pred"] == 1]
        src         = attack_rows if len(attack_rows) > 0 else df
        top_ports   = {
            str(int(k)): int(v)
            for k, v in src["Destination Port"].value_counts().head(5).items()
        }
    else:
        top_ports = {}

    # ── Anomaly score timeline (60 buckets) ───────────────────────────────
    n_buckets      = 60
    bucket_size    = max(1, len(error) // n_buckets)
    anomaly_series = [
        round(float(np.mean(error[i: i + bucket_size])), 6)
        for i in range(0, len(error), bucket_size)
    ][:n_buckets]

    # ── SHAP — small sample for explanation display only ──────────────────
    # SHAP does not affect attack/benign counts — it is display only
    print("▶ Computing SHAP values...", flush=True)
    explainer  = shap.TreeExplainer(rf)
    attack_idx = np.where(rf_preds == 1)[0]
    benign_idx = np.where(rf_preds == 0)[0]
    rng        = np.random.RandomState(42)

    n_atk   = min(25, len(attack_idx))
    n_ben   = min(25, len(benign_idx))
    sel_atk = rng.choice(attack_idx, n_atk, replace=False) if n_atk > 0 else np.array([], dtype=int)
    sel_ben = rng.choice(benign_idx, n_ben, replace=False) if n_ben > 0 else np.array([], dtype=int)
    sel_all = np.concatenate([sel_atk, sel_ben]).astype(int)

    # Re-align only the SHAP sample rows (tiny, no memory risk)
    X_shap      = align_features(df.iloc[sel_all], EXPECTED_FEATURES)
    shap_values = explainer(X_shap)
    del X_shap
    gc.collect()

    vals = shap_values.values
    if vals.ndim == 3:
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
            "prediction":    int(rf_preds[idx]),
            "anomaly_score": round(float(error[idx]), 5),
            "is_anomaly":    bool(error[idx] > threshold),
            "shap_values":   shap_dict,
        }
        if "Destination Port" in df.columns:
            try:
                flow["destination_port"] = str(int(df["Destination Port"].iloc[idx]))
            except Exception:
                flow["destination_port"] = "?"
        flows.append(flow)

    flows.sort(key=lambda f: (-f["prediction"], -f["anomaly_score"]))
    print(f"▶ Done. {total_rows} rows analysed. {len(flows)} flows with SHAP.", flush=True)

    return {
        "attacks":        attack_count,
        "benign":         benign_count,
        "anomalies":      anomaly_count,
        "top_ports":      top_ports,
        "anomaly_series": anomaly_series,
        "flows":          flows,
    }