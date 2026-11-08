#!/bin/sh
set -e

echo "Fetching Fog keys from gs://${FOG_KEYS_BUCKET}/dot8_keys.tar.gz..."
mkdir -p /fog

TOKEN=$(curl -s -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" \
  | jq -r '.access_token')

curl -s -H "Authorization: Bearer ${TOKEN}" \
  -o /fog/dot8_keys.tar.gz \
  "https://storage.googleapis.com/storage/v1/b/${FOG_KEYS_BUCKET}/o/dot8_keys.tar.gz?alt=media"

tar xzf /fog/dot8_keys.tar.gz -C /fog/
echo "Keys ready at ${FOG_KEYS_DIR}"

exec /main
