#!/bin/sh
set -e

echo "Fetching Fog keys from gs://${FOG_KEYS_BUCKET}/dot8_keys.tar.gz..."
mkdir -p /fog
python3 -c "
from google.cloud import storage
client = storage.Client()
bucket = client.bucket('${FOG_KEYS_BUCKET}')
blob = bucket.blob('dot8_keys.tar.gz')
blob.download_to_filename('/fog/dot8_keys.tar.gz')
print('downloaded')
"
tar xzf /fog/dot8_keys.tar.gz -C /fog/
echo "Keys ready at ${FOG_KEYS_DIR}"

exec /main
