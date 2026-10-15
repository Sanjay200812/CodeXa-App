const fs = require('fs');
const path = require('path');

const envPath = path.resolve(__dirname, '../../CodeXa/codexa-portfolio/.env');
const env = fs.readFileSync(envPath, 'utf8');

const urlMatch = env.match(/SUPABASE_URL=["']?([^"'\r\n]+)/);
const keyMatch = env.match(/SUPABASE_SERVICE_ROLE_KEY=["']?([^"'\r\n]+)/) || env.match(/SUPABASE_SECRET_KEY=["']?([^"'\r\n]+)/);

const url = urlMatch ? urlMatch[1].trim() : '';
const key = keyMatch ? keyMatch[1].trim() : '';

console.log('Connecting to Supabase at:', url);

async function run() {
  const res = await fetch(url + '/storage/v1/bucket', {
    headers: {
      'apikey': key,
      'Authorization': 'Bearer ' + key,
    },
  });
  console.log('Buckets status:', res.status);
  const json = await res.json();
  console.log('Buckets list:', json);
}

run().catch(console.error);
