# data_loader.mojo
# Mojo owns the entry point and control flow. Python is called ONLY for
# kagglehub (no Mojo equivalent exists) — same interop boundary pattern
# as main.mojo's HTTP server and Fog client.

from std.python import Python

def main() raises:
    var kagglehub = Python.import_module("kagglehub")
    print("Mojo: requesting dataset via Python boundary...")

    var path = kagglehub.dataset_download("mlg-ulb/creditcardfraud")

    print("Mojo: dataset downloaded to:")
    print(path)
