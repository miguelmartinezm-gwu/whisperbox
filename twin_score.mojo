# twin_score.mojo
# Cleartext twin: pure Mojo arithmetic (builtin-only), no Python.
# Real values from train_scorer.mojo's output on the actual
# Credit Card Fraud dataset (V1-V8).

def dot8(a0: Float64, a1: Float64, a2: Float64, a3: Float64, a4: Float64, a5: Float64, a6: Float64, a7: Float64,
         b0: Float64, b1: Float64, b2: Float64, b3: Float64, b4: Float64, b5: Float64, b6: Float64, b7: Float64) -> Float64:
    return (a0*b0) + (a1*b1) + (a2*b2) + (a3*b3) + (a4*b4) + (a5*b5) + (a6*b6) + (a7*b7)

def sigmoid(x: Float64) -> Float64:
    # logistic function, manual (no stdlib math needed for this scale)
    var e = 2.718281828459045
    # e^-x via repeated multiplication is overkill here; use a simple
    # Taylor-free approach is not accurate enough -- flag: needs real exp.
    # Placeholder until we confirm Mojo's math module resolves (M6 note).
    return 1.0 / (1.0 + x)  # NOTE: NOT real sigmoid, see printed warning

def main():
    # Fraud centroid (L2-normalized)
    var c0: Float64 = -0.39064416
    var c1: Float64 = 0.29665194
    var c2: Float64 = -0.57576276
    var c3: Float64 = 0.37182237
    var c4: Float64 = -0.2579675
    var c5: Float64 = -0.11442238
    var c6: Float64 = -0.45587087
    var c7: Float64 = 0.04671374

    # Logistic regression weights
    var w0: Float64 = 0.41494812
    var w1: Float64 = 0.26114871
    var w2: Float64 = -0.50499648
    var w3: Float64 = 1.4433092
    var w4: Float64 = -0.23793771
    var w5: Float64 = -0.85344488
    var w6: Float64 = -0.04841834
    var w7: Float64 = -0.26360391
    var intercept: Float64 = -8.52625175

    # Real fraud row (V1-V8)
    var f0: Float64 = -2.31222654
    var f1: Float64 = 1.95199201
    var f2: Float64 = -1.60985073
    var f3: Float64 = 3.99790559
    var f4: Float64 = -0.52218786
    var f5: Float64 = -1.42654532
    var f6: Float64 = -2.53738731
    var f7: Float64 = 1.39165725

    # Real normal row (V1-V8)
    var n0: Float64 = -1.35980713
    var n1: Float64 = -0.07278117
    var n2: Float64 = 2.53634674
    var n3: Float64 = 1.37815522
    var n4: Float64 = -0.33832077
    var n5: Float64 = 0.46238778
    var n6: Float64 = 0.23959855
    var n7: Float64 = 0.0986979

    # --- Method A: cosine-ish dot product against centroid ---
    var fraud_cos = dot8(f0,f1,f2,f3,f4,f5,f6,f7, c0,c1,c2,c3,c4,c5,c6,c7)
    var normal_cos = dot8(n0,n1,n2,n3,n4,n5,n6,n7, c0,c1,c2,c3,c4,c5,c6,c7)

    # --- Method B: logistic regression raw score (pre-sigmoid) ---
    var fraud_logit = dot8(f0,f1,f2,f3,f4,f5,f6,f7, w0,w1,w2,w3,w4,w5,w6,w7) + intercept
    var normal_logit = dot8(n0,n1,n2,n3,n4,n5,n6,n7, w0,w1,w2,w3,w4,w5,w6,w7) + intercept

    print('{"method": "cosine_dot", "fraud_row_score": ' + String(fraud_cos) + ', "normal_row_score": ' + String(normal_cos) + '}')
    print('{"method": "logistic_raw_score", "fraud_row_score": ' + String(fraud_logit) + ', "normal_row_score": ' + String(normal_logit) + '}')
