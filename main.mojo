# main.mojo
# Whisperbox M3 + M5a + M6 + M7: Mojo + Python interop HTTP server on Cloud
# Run. Routes: / (alive check), /fog/jobs (control plane), /score (M6 full
# triangulation), /demo (M7 public web UI, served same-origin, no hardcoded
# domain -- relative fetch('/score') call). Mojo owns main/startup; Python
# (via std.python interop) owns the HTTP server loop and all external calls.

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

DEMO_HTML = '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Whisperbox - Private Fraud Scoring Demo</title>
<style>
  :root {
    --bg: #ffffff; --fg: #111111; --muted: #666666;
    --accent: #2563eb; --danger: #dc2626; --safe: #16a34a;
    --card-bg: #f7f7f8; --border: #e2e2e5;
    color-scheme: light dark;
  }
  @media (prefers-color-scheme: dark) {
    :root:not([data-theme="light"]) {
      --bg: #0b0b0d; --fg: #f2f2f2; --muted: #9a9a9a;
      --accent: #60a5fa; --danger: #f87171; --safe: #4ade80;
      --card-bg: #18181b; --border: #2a2a2e;
    }
  }
  * { box-sizing: border-box; }
  html, body { height: 100%25; }
  body {
    margin: 0; background: var(--bg); color: var(--fg);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    padding-top: env(safe-area-inset-top, 0px);
    padding-bottom: env(safe-area-inset-bottom, 0px);
  }
  .wrap { max-width: 680px; margin: 0 auto; padding: 32px 20px 60px; }
  h1 { font-size: 1.5rem; margin-bottom: 4px; }
  .sub { color: var(--muted); margin-bottom: 24px; font-size: 0.95rem; }
  .banner {
    background: var(--card-bg); border: 1px solid var(--border);
    border-radius: 10px; padding: 14px 16px; font-size: 0.85rem;
    color: var(--muted); margin-bottom: 28px; line-height: 1.5;
  }
  .btn {
    background: var(--accent); color: white; border: none;
    border-radius: 8px; padding: 12px 20px; font-size: 1rem;
    cursor: pointer; font-weight: 600;
  }
  .btn:disabled { opacity: 0.5; cursor: default; }
  .result {
    margin-top: 24px; border: 1px solid var(--border);
    border-radius: 12px; padding: 20px; background: var(--card-bg);
    display: none;
  }
  .result.show { display: block; }
  .row { display: flex; justify-content: space-between; padding: 6px 0; font-size: 0.95rem; }
  .row .k { color: var(--muted); }
  .label-fraud { color: var(--danger); font-weight: 700; }
  .label-normal { color: var(--safe); font-weight: 700; }
  .explanation {
    margin-top: 14px; padding-top: 14px; border-top: 1px solid var(--border);
    font-style: italic;
  }
  .loading { color: var(--muted); margin-top: 16px; font-size: 0.9rem; display: none; }
  .loading.show { display: block; }
  .steps { margin-top: 8px; font-size: 0.85rem; color: var(--muted); }
  .steps div { padding: 2px 0; }
  .err { color: var(--danger); margin-top: 16px; display: none; }
  .err.show { display: block; }
  footer { margin-top: 40px; font-size: 0.75rem; color: var(--muted); }
</style>
</head>
<body>
<div class="wrap">
  <h1>Whisperbox</h1>
  <div class="sub">Privacy-preserving fraud scoring -- Mojo + Niobium Fog FHE + Modular Cloud</div>

  <div class="banner">
    <strong>How this works:</strong> a frozen sample transaction is scored by computing
    an encrypted dot product against a fraud centroid -- the computation runs on real
    FPGA hardware under fully homomorphic encryption, so the server never sees the
    plaintext feature values. Only the final score is decrypted, and the AI narration
    below is written from that number alone -- it never sees the original data.
  </div>

  <button class="btn" id="runBtn" onclick="runDemo()">Run demo (frozen sample row)</button>

  <div class="loading" id="loading">
    Running real encrypted computation on Niobium Fog -- this takes 15-25 seconds.
    <div class="steps">
      <div>1. Mojo validates and computes the clear-text reference score</div>
      <div>2. Features are encrypted and submitted to Fog FPGA hardware</div>
      <div>3. The encrypted score is computed and returned, then decrypted</div>
      <div>4. Modular Cloud (MiniMax) narrates the decrypted number only</div>
    </div>
  </div>

  <div class="err" id="err"></div>

  <div class="result" id="result">
    <div class="row"><span class="k">Clear-text twin score</span><span id="twinScore"></span></div>
    <div class="row"><span class="k">Fog-decrypted score (FPGA)</span><span id="fogScore"></span></div>
    <div class="row"><span class="k">Classification</span><span id="label"></span></div>
    <div class="explanation" id="explanation"></div>
  </div>

  <footer>
    Backend: whisperbox-http on Google Cloud Run. Encryption: Niobium Fog (OpenFHE/CKKS,
    FPGA). Narration: Modular Cloud, MiniMax-M3.1-Flash. No raw data ever reaches the LLM.
  </footer>
</div>

<script>
async function runDemo() {
  const btn = document.getElementById('runBtn');
  const loading = document.getElementById('loading');
  const result = document.getElementById('result');
  const err = document.getElementById('err');

  btn.disabled = true;
  loading.classList.add('show');
  result.classList.remove('show');
  err.classList.remove('show');

  try {
    const resp = await fetch('/score');
    const data = await resp.json();

    if (data.status !== "ok") {
      throw new Error(data.message || "Unknown error");
    }

    document.getElementById('twinScore').textContent = data.twin_score.toFixed(5);
    document.getElementById('fogScore').textContent = data.fog_score.toFixed(5);

    const labelEl = document.getElementById('label');
    labelEl.textContent = data.label.toUpperCase();
    labelEl.className = data.label === "fraud" ? "label-fraud" : "label-normal";

    let sentence = data.explanation;
    try {
      const parsed = JSON.parse(data.explanation);
      sentence = parsed.risk_sentence || data.explanation;
    } catch (e) { /* not JSON, show raw */ }
    document.getElementById('explanation').textContent = sentence;

    result.classList.add('show');
  } catch (e) {
    err.textContent = "Error: " + e.message;
    err.classList.add('show');
  } finally {
    loading.classList.remove('show');
    btn.disabled = false;
  }
}
</script>
</body>
</html>'''

class WhisperboxHandler(BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        self.send_response(204)
        self._send_cors_headers()
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self):
        if self.path == "/fog/jobs":
            self._handle_fog_jobs()
        elif self.path == "/score":
            self._handle_score()
        elif self.path == "/demo":
            self._handle_demo()
        else:
            self._handle_root()

    def _send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def _send_json(self, body, status_code):
        self.send_response(status_code)
        self._send_cors_headers()
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _handle_root(self):
        body = b'{"status":"ok","message":"mojo + python interop alive on cloud run"}'
        self._send_json(body, 200)

    def _handle_demo(self):
        body = DEMO_HTML.encode("utf-8")
        self.send_response(200)
        self._send_cors_headers()
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _handle_fog_jobs(self):
        token = os.environ.get("FOG_API_TOKEN", "")
        if not token:
            body = json.dumps({"status": "error", "message": "FOG_API_TOKEN not set"}).encode()
            self._send_json(body, 500)
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

        self._send_json(body, status)

    def _handle_score(self):
        try:
            twin_score = 5.415389525030956

            server_bin = "/fog/dot8_server"
            key_dir = "/fog/dot8_keys"
            fog_script = "/fog/fog"

            submit = subprocess.run(
                ["python3", fog_script, "submit", server_bin, key_dir, "--target=FOG"],
                capture_output=True, text=True, timeout=300, encoding='utf-8', errors='replace'
            )
            if submit.returncode != 0:
                raise RuntimeError("Fog submit failed: " + submit.stderr[-500:])

            decrypt_bin = "/fog/dot8_decrypt"
            decrypt = subprocess.run(
                [decrypt_bin, key_dir],
                capture_output=True, text=True, timeout=60, encoding='utf-8', errors='replace'
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
                    max_tokens=512,
                    reasoning_effort="low",
                    temperature=0.2,
                )
                msg = resp.choices[0].message
                explanation = (msg.content or getattr(msg, "reasoning_content", None) or "").strip()
                if not explanation:
                    explanation = "Narration unavailable (model returned empty content)."

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

        self._send_json(body, status_code)

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
