const { Client } = require('G:/AntiGravity IDE/CodeXa/codexa-portfolio/node_modules/pg');
const fs = require('fs');
const path = require('path');

const envPath = path.resolve(__dirname, '../../CodeXa/codexa-portfolio/.env');
const env = fs.readFileSync(envPath, 'utf8');

const dbUrlMatch = env.match(/DIRECT_URL=["']?([^"'\r\n]+)/) || env.match(/DATABASE_URL=["']?([^"'\r\n]+)/);
const connectionString = dbUrlMatch ? dbUrlMatch[1].trim() : '';

const client = new Client({
  connectionString,
  ssl: { rejectUnauthorized: false },
});

async function run() {
  await client.connect();
  await client.query('ALTER TABLE public.post_views ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();');
  await client.query('ALTER TABLE public.post_views ADD COLUMN IF NOT EXISTS viewed_at TIMESTAMPTZ DEFAULT now();');
  const cols = await client.query('SELECT column_name FROM information_schema.columns WHERE table_name = \'post_views\';');
  console.log('post_views columns:', cols.rows.map(r => r.column_name));
  await client.end();
}

run().catch(console.error);
