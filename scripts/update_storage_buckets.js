const fs = require('fs');
const path = require('path');

const envPath = path.resolve(__dirname, '../../CodeXa/codexa-portfolio/.env');
const env = fs.readFileSync(envPath, 'utf8');

const urlMatch = env.match(/SUPABASE_URL=["']?([^"'\r\n]+)/);
const keyMatch = env.match(/SUPABASE_SERVICE_ROLE_KEY=["']?([^"'\r\n]+)/) || env.match(/SUPABASE_SECRET_KEY=["']?([^"'\r\n]+)/);

const url = urlMatch ? urlMatch[1].trim() : '';
const key = keyMatch ? keyMatch[1].trim() : '';

const allowedMimes = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
  'video/mp4',
  'video/webm',
  'video/quicktime',
  'video/3gpp',
  'video/x-matroska',
  'application/pdf',
];

async function updateBucket(bucketId) {
  const endpoint = `${url}/storage/v1/bucket/${bucketId}`;
  const res = await fetch(endpoint, {
    method: 'PUT',
    headers: {
      'apikey': key,
      'Authorization': `Bearer ${key}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      public: true,
      file_size_limit: 52428800, // 50 MB
      allowed_mime_types: allowedMimes,
    }),
  });
  console.log(`Updated ${bucketId}:`, res.status, await res.text());
}

async function run() {
  await updateBucket('post-images');
  await updateBucket('chat-images');
  await updateBucket('documents');
  await updateBucket('project-images');
}

run().catch(console.error);
