# train_scorer.mojo
# Mojo owns main. Python boundary for pandas (data) and sklearn (model
# fitting — no Mojo equivalent exists for either).
#
# Computes, from the real Credit Card Fraud dataset:
#   1. A fraud centroid vector (mean of V1-V8 across fraud rows, L2-normalized)
#   2. Logistic regression weights (V1-V8 -> Class), fit in the clear
# Both get printed so we can hardcode them into the Fog circuit test —
# same "offline training, fixed weights at inference" pattern Grok specified.

from std.python import Python

def main() raises:
    var pandas = Python.import_module("pandas")
    var np = Python.import_module("numpy")
    var sklearn_linear = Python.import_module("sklearn.linear_model")
    var sklearn_preprocess = Python.import_module("sklearn.preprocessing")

    var csv_path = "/home/mickeymesmu/.cache/kagglehub/datasets/mlg-ulb/creditcardfraud/versions/3/creditcard.csv"
    print("Mojo: loading dataset...")
    var df = pandas.read_csv(csv_path)

    var feature_cols = Python.evaluate("['V1','V2','V3','V4','V5','V6','V7','V8']")
    var X = df[feature_cols]
    var y = df["Class"]

    # --- Method A: cosine similarity centroid ---
    print("Mojo: computing fraud centroid (cosine method)...")
    var fraud_rows = X[y == 1]
    var centroid = np.array(fraud_rows.mean(axis=0))
    var centroid_norm = centroid / np.linalg.norm(centroid)
    print("Centroid (L2-normalized):")
    print(centroid_norm)

    # --- Method B: logistic regression weights ---
    print("Mojo: training logistic regression (clear, offline)...")
    var scaler = sklearn_preprocess.StandardScaler()
    var X_scaled = scaler.fit_transform(X)
    var model = sklearn_linear.LogisticRegression(max_iter=1000)
    _ = model.fit(X_scaled, y)
    print("Logistic regression weights:")
    print(model.coef_)
    print("Intercept:")
    print(model.intercept_)

    # --- Pick one real fraud row and one real normal row as test inputs ---
    var fraud_sample = X[y == 1].iloc[0]
    var normal_sample = X[y == 0].iloc[0]
    print("Sample fraud row (V1-V8):")
    print(np.array(fraud_sample))
    print("Sample normal row (V1-V8):")
    print(np.array(normal_sample))
