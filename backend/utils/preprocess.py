def align_features(df, expected_features):
    df = df.copy()
    df.columns = df.columns.str.strip()

    for col in expected_features:
        if col not in df.columns:
            df[col] = 0

    return df[expected_features]
