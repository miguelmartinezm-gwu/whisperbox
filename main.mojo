# main.mojo
# Whisperbox M3 + M5a: Mojo + Python interop HTTP server on Cloud Run,
# now with a /fog/jobs route bridging to Niobium's control-plane API.
# Mojo owns main/startup; Python (via std.python interop) owns the
# HTTP server loop and the Niobium HTTPS call — the one legitimate
# Python boundary per project convention (no native Mojo sockets/HTTP
# client yet).

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

class WhisperboxHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/fog/jobs":
            self._handle_fog_jobs()
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

    def log_message(self, format, *args):
        pass
"""

    var exec_globals = Python.dict()
    builtins.exec(handler_src, exec_globals)
    var handler_class = exec_globals["WhisperboxHandler"]

    # CRITICAL: Python tuple, not Mojo ("0.0.0.0", port)
    var host = Python.evaluate("'0.0.0.0'")
    var addr = builtins.tuple(Python.list(host, port))

    socketserver.ThreadingTCPServer.allow_reuse_address = True
    var server = socketserver.ThreadingTCPServer(addr, handler_class)

    print("Mojo+Python HTTP server listening")
    sys.stdout.flush()
    server.serve_forever()
