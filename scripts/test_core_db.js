const { Client } = require('G:/AntiGravity IDE/CodeXa/codexa-portfolio/node_modules/pg');
const fs = require('fs');
const path = require('path');

const envPath = path.resolve(__dirname, '../../CodeXa/codexa-portfolio/.env');
const env = fs.readFileSync(envPath, 'utf8');

const dbUrlMatch = env.match(/DIRECT_URL=["']?([^"'\r\n]+)/) || env.match(/DATABASE_URL=["']?([^"'\r\n]+)/);
const connectionString = dbUrlMatch ? dbUrlMatch[1].trim() : '';

console.log('Connecting to Core DB pooler...');

const client = new Client({
  connectionString,
  ssl: { rejectUnauthorized: false },
});

async function run() {
  await client.connect();
  console.log('Connected to Core Postgres!');
  const res = await client.query('SELECT column_name FROM information_schema.columns WHERE table_name = \'MobileSession\';');
  console.log('MobileSession columns:', res.rows.map(r => r.column_name));
  await client.end();
}

run().catch(console.error);
