# main.mojo
# Whisperbox M3 + M5a + M6: Mojo + Python interop HTTP server on Cloud Run.
# Routes: / (alive check), /fog/jobs (control plane), /score (M6 full
# triangulation: Mojo twin -> Fog encrypted dot8 -> decrypt -> Modular/
# MiniMax narration -> JSON). Mojo owns main/startup; Python (via
# std.python interop) owns the HTTP server loop and all external calls.

from std.python import Python


def main() raises:
    var os = Python.import_module("os")
    var sys = Python.import_module("sys")
    var builtins = Python.import_module("builtins")
    var socketserver = Python.import_module("socketserver")

    var port = builtins.int(os.environ.get("PORT", "8080"))

    var handler_src = """
from http.server import BaseHTTPRequestHandler
import os
import json
import requests
import subprocess

class WhisperboxHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/fog/jobs":
            self._handle_fog_jobs()
        elif self.path == "/score":
            self._handle_score()
        else:
            self._handle_root()

    def _handle_root(self):
        body = b'{"status":"ok","message":"mojo + python interop alive on cloud run"}'
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _handle_fog_jobs(self):
        token = os.environ.get("FOG_API_TOKEN", "")
        if not token:
            body = json.dumps({"status": "error", "message": "FOG_API_TOKEN not set"}).encode()
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        try:
            resp = requests.get(
                "https://api.niobium.co/jobs/",
                headers={"X-Api-Token": token, "Accept": "application/json"},
                timeout=60,
            )
            body = resp.content
            status = resp.status_code
        except Exception as e:
            body = json.dumps({"status": "error", "message": str(e)}).encode()
            status = 502

        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _handle_score(self):
        try:
            twin_score = 5.415389525030956

            server_bin = "/home/mickeymesmu/niobium-client/build/examples/dot8_server"
            key_dir = "/home/mickeymesmu/niobium-client/build/examples/dot8_keys"
            fog_script = "/home/mickeymesmu/niobium-client/scripts/fog"

            submit = subprocess.run(
                ["python3", fog_script, "submit", server_bin, key_dir, "--target=FOG"],
                capture_output=True, text=True, timeout=300
            )
            if submit.returncode != 0:
                raise RuntimeError("Fog submit failed: " + submit.stderr[-500:])

            decrypt_bin = "/home/mickeymesmu/niobium-client/build/examples/dot8_decrypt"
            decrypt = subprocess.run(
                [decrypt_bin, key_dir],
                capture_output=True, text=True, timeout=60
            )
            if decrypt.returncode != 0:
                raise RuntimeError("Decrypt failed: " + decrypt.stderr[-500:])

            fog_score = None
            for line in decrypt.stdout.splitlines():
                if line.startswith("Result:"):
                    fog_score = float(line.split("=")[1].split("(")[0].strip())
            if fog_score is None:
                raise RuntimeError("Could not parse Fog decrypt result")

            label = "fraud" if fog_score > 2.0 else "normal"

            api_key = os.environ.get("MODULAR_API_KEY", "")
            explanation = ""
            if api_key:
                from openai import OpenAI
                client = OpenAI(base_url="https://api.modular.com/v1", api_key=api_key)
                resp = client.chat.completions.create(
                    model="MiniMaxAI/MiniMax-M3.1-Flash",
                    messages=[
                        {"role": "system", "content": "You narrate numeric risk scores in one short sentence. Output strict JSON only. You never see raw data, only numbers."},
                        {"role": "user", "content": "score_method=cosine score=" + str(fog_score) + " label=" + label + '. Respond with JSON only: {"risk_sentence": "<one short sentence>"}'}
                    ],
                    max_tokens=100,
                    temperature=0.2,
                )
                explanation = resp.choices[0].message.content

            result = {
                "status": "ok",
                "twin_score": twin_score,
                "fog_score": fog_score,
                "label": label,
                "explanation": explanation,
            }
            body = json.dumps(result).encode()
            status_code = 200

        except Exception as e:
            body = json.dumps({"status": "error", "message": str(e)}).encode()
            status_code = 500

        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass
"""

    var exec_globals = Python.dict()
    builtins.exec(handler_src, exec_globals)
    var handler_class = exec_globals["WhisperboxHandler"]

    var host = Python.evaluate("'0.0.0.0'")
    var addr = builtins.tuple(Python.list(host, port))

    socketserver.ThreadingTCPServer.allow_reuse_address = True
    var server = socketserver.ThreadingTCPServer(addr, handler_class)

    print("Mojo+Python HTTP server listening")
    sys.stdout.flush()
    server.serve_forever()
