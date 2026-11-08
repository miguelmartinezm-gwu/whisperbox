# fog_decrypt_dot8.mojo
# Mojo owns main. Python boundary ONLY for subprocess invocation of the
# compiled dot8_decrypt binary (no Mojo equivalent for process execution).

from std.python import Python

def main() raises:
    var subprocess = Python.import_module("subprocess")

    var decrypt_bin = "/home/mickeymesmu/niobium-client/build/examples/dot8_decrypt"
    var key_dir = "/home/mickeymesmu/niobium-client/build/examples/dot8_keys"

    var cmd = Python.list()
    cmd.append(decrypt_bin)
    cmd.append(key_dir)

    var result = subprocess.run(cmd, capture_output=True, text=True)

    print("--- stdout ---")
    print(result.stdout)
    print("--- stderr ---")
    print(result.stderr)
    print("--- exit code ---")
    print(result.returncode)
