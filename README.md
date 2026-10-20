# whisperbox

Privacy-preserving fraud scoring: real tabular data, encrypted computation on real FPGA hardware, AI-narrated results.

## Architecture (mandatory stack, locked)

| Component | Role | Status |
|---|---|---|
| Mojo | Compiled service entry point, validation, cleartext twin, orchestration | Mandatory — implemented |
| MAX | Hosts the small LLM that narrates decrypted scores (numbers only, never raw data) | Mandatory — pending |
| Niobium Fog (FHE) | Encrypted computation — the actual privacy claim | Mandatory — next build |
| Python | Interop boundary only (pandas/sklearn/kagglehub for data prep, Niobium SDK, HTTP) — never the primary app | Boundary, not core |

Interop rule: every utility is Mojo-owned (def main()), with Python imported only where Mojo's stdlib has no equivalent (data science libraries, sockets, the Niobium SDK). Mojo is never a thin wrapper around a Python script.

## What this proves

A real tabular dataset (Kaggle/ULB Credit Card Fraud, 284,807 rows, 492 labeled fraud cases) is scored two ways — cosine similarity to a fraud centroid, and a logistic regression model — computed on encrypted features, on real FPGA hardware, without the compute provider ever seeing the plaintext data. The decrypted score is then explained in plain language by an LLM that only ever sees the number, never the original record.

real row -> Mojo (validate, cleartext twin)
         -> encrypt (Python + niobium-client)
         -> Niobium Fog: dot product on ciphertext (FPGA)
         -> decrypt -> score
         -> MAX-hosted LLM: narrate the number
         -> JSON response

## Honest scope — what this is NOT

- Not a chatbot. The LLM only narrates a final decrypted score, never processes raw private input.
- Not full-LLM-under-FHE — that's not currently possible for anyone, on any stack. FHE here computes a fixed, small numeric circuit (dot product / linear score), not transformer inference.
- MiniLM (MAX's embedding model) is not used as the tabular fraud classifier — wrong tool for 8 numeric features; kept for future text-based use cases if added.

## Milestones (status as of this README)

- [x] M1 — Mojo binary runs on Cloud Run
- [x] M2 — Real Mojo compute, verified correct
- [x] M3 — Mojo + Python HTTP service, live on Cloud Run
- [x] M4 — MAX serving real embeddings on Cloud Run (CPU; GPU pending quota)
- [x] M5a — Niobium Fog control plane reachable from Cloud Run
- [x] M5b — Real encrypted multiply on real FPGA hardware, verified correct (91 ~= 91)
- [x] Real dataset pipeline — fraud centroid + logistic regression trained on real data, Mojo cleartext twin verified
- [x] GitHub CI/CD — push to main auto-builds and deploys whisperbox-http
- [ ] Fog 8-dimensional dot product on real fraud/centroid/weight vectors (in progress)
- [ ] MAX-hosted LLM narration of decrypted scores
- [ ] Full triangulation: one request, Mojo -> MAX -> Fog -> MAX, end to end

## Local development

source admin.sh   (loads PROJECT_ID, REGION, FOG_API_TOKEN, and wb_* helper commands)

See admin.sh for available commands (wb_build, wb_deploy_http, wb_test_http, wb_diskcheck, etc.)

## Services

- whisperbox-http — Cloud Run Service, Mojo + Python HTTP, control-plane Fog access
- whisperbox-max-cpu — Cloud Run Service, MAX serving MiniLM embeddings
