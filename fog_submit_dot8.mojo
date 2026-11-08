# fog_submit_dot8.mojo
# Mojo owns main. Python is the boundary ONLY for subprocess invocation
# of niobium-client's scripts/fog (a Python CLI wrapper around the C++
# transport binary) — no Mojo equivalent for process execution exists.
# Same pattern as main.mojo's /fog/jobs control-plane call.

from std.python import Python

def main() raises:
    var subprocess = Python.import_module("subprocess")
    var os = Python.import_module("os")

    # FOG_API_TOKEN must already be in the environment (Secret Manager
    # in Cloud Run; exported from Secret Manager in Cloud Shell sessions).
    var token = os.environ.get("FOG_API_TOKEN", "")
    if String(token).byte_length() == 0:
        print('{"error": "FOG_API_TOKEN not set"}')
        return

    print("Mojo: submitting dot8_server to Fog via scripts/fog...")

    var server_bin = "/home/mickeymesmu/niobium-client/build/examples/dot8_server"
    var key_dir = "/home/mickeymesmu/niobium-client/build/examples/dot8_keys"
    var fog_script = "/home/mickeymesmu/niobium-client/scripts/fog"

    var cmd = Python.list()
    cmd.append("python3")
    cmd.append(fog_script)
    cmd.append("submit")
    cmd.append(server_bin)
    cmd.append(key_dir)
    cmd.append("--target=FOG")

    var result = subprocess.run(cmd, capture_output=True, text=True)

    print("--- stdout ---")
    print(result.stdout)
    print("--- stderr ---")
    print(result.stderr)
    print("--- exit code ---")
    print(result.returncode)
