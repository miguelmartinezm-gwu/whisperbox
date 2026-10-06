#!/bin/bash
# whisperbox admin script — source this at the start of every session:
#   source ~/whisperbox-m1/whisperbox-m1/admin.sh
# Re-run any time the terminal reconnects after inactivity/disconnect.

set -a  # auto-export everything below

PROJECT_ID=whisperbox-510521
REGION=us-central1
PROJECT_DIR=~/whisperbox-m1/whisperbox-m1

set +a

cd "$PROJECT_DIR" || { echo "ERROR: project folder not found"; return 1; }
gcloud config set project "$PROJECT_ID" > /dev/null

echo "whisperbox admin env loaded."
echo "  PROJECT_ID=$PROJECT_ID"
echo "  REGION=$REGION"
echo "  cwd=$(pwd)"
echo ""
echo "Available commands:"
echo "  wb_build <tag>         - gcloud builds submit with given tag"
echo "  wb_deploy_http         - deploy whisperbox-http service"
echo "  wb_test_http           - curl the deployed whisperbox-http service"
echo "  wb_deploy_max_cpu      - deploy whisperbox-max-cpu service"
echo "  wb_test_max_cpu        - curl an embeddings request"
echo "  wb_logs <job-name>     - read latest Cloud Run Job execution logs"

wb_build() {
  gcloud builds submit --project="$PROJECT_ID" --tag="gcr.io/$PROJECT_ID/$1"
}

wb_deploy_http() {
  gcloud run deploy whisperbox-http \
    --image="gcr.io/$PROJECT_ID/whisperbox-http" \
    --region="$REGION" --project="$PROJECT_ID" \
    --allow-unauthenticated --port=8080
}

wb_test_http() {
  local url
  url=$(gcloud run services describe whisperbox-http --region="$REGION" --project="$PROJECT_ID" --format='value(status.url)')
  curl -s "$url"; echo
}

wb_deploy_max_cpu() {
  gcloud run deploy whisperbox-max-cpu \
    --image="gcr.io/$PROJECT_ID/max-nvidia-full:latest" \
    --region="$REGION" --project="$PROJECT_ID" \
    --port=8000 --cpu=4 --memory=16Gi --no-cpu-throttling \
    --allow-unauthenticated --timeout=900 \
    --set-env-vars="HF_TOKEN=${HF_TOKEN:-}" \
    --args="--model,sentence-transformers/all-MiniLM-L6-v2,--devices,cpu"
}

wb_test_max_cpu() {
  local url
  url=$(gcloud run services describe whisperbox-max-cpu --region="$REGION" --project="$PROJECT_ID" --format='value(status.url)')
  curl -s "$url/v1/embeddings" -H "Content-Type: application/json" \
    -d '{"model": "sentence-transformers/all-MiniLM-L6-v2", "input": "test"}'; echo
}

wb_logs() {
  local exec_name
  exec_name=$(gcloud run jobs executions list --job="$1" --region="$REGION" --project="$PROJECT_ID" --limit=1 --format='value(name)')
  gcloud logging read \
    "resource.type=cloud_run_job AND resource.labels.job_name=$1 AND labels.\"run.googleapis.com/execution_name\"=\"$exec_name\"" \
    --project="$PROJECT_ID" --limit=50 --format="table(timestamp,textPayload)" --order=asc
}


# --- Niobium Fog SDK env ---
export FOG_API_TOKEN=$(gcloud secrets versions access latest --secret=FOG_API_TOKEN --project=$PROJECT_ID 2>/dev/null)
export NIOBIUM_VENV=~/fhe_test

fog_activate() {
  source "$NIOBIUM_VENV/bin/activate"
  cd ~/niobium-client
  echo "niobium venv activated, FOG_API_TOKEN loaded: ${FOG_API_TOKEN:0:8}..."
}
