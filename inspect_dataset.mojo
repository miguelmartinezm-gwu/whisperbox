# inspect_dataset.mojo
# Mojo owns the entry point and control flow. Python is called ONLY for
# pandas (no Mojo equivalent exists for CSV/dataframe handling) — same
# interop boundary pattern as data_loader.mojo and main.mojo.

from std.python import Python

def main() raises:
    var pandas = Python.import_module("pandas")

    var csv_path = "/home/mickeymesmu/.cache/kagglehub/datasets/mlg-ulb/creditcardfraud/versions/3/creditcard.csv"
    print("Mojo: loading dataset via Python/pandas boundary...")

    var df = pandas.read_csv(csv_path)

    print("Mojo: dataset shape:")
    print(df.shape)

    print("Mojo: columns:")
    print(df.columns.tolist())

    print("Mojo: class distribution (0=normal, 1=fraud):")
    var class_counts = df["Class"].value_counts()
    print(class_counts)
