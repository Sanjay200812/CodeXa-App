const { Client } = require('G:/AntiGravity IDE/CodeXa/codexa-portfolio/node_modules/pg');
const fs = require('fs');
const path = require('path');

const envPath = path.resolve(__dirname, '../../CodeXa/codexa-portfolio/.env');
const env = fs.readFileSync(envPath, 'utf8');

const dbUrlMatch = env.match(/CHAT_SUPABASE_DB_URL=["']?([^"'\r\n]+)/) || env.match(/CHAT_SUPABASE_DIRECT_URL=["']?([^"'\r\n]+)/);
const connectionString = dbUrlMatch ? dbUrlMatch[1].trim() : '';

console.log('Connecting to Chat Supabase pooler...');

const client = new Client({
  connectionString,
  ssl: { rejectUnauthorized: false },
});

async function run() {
  await client.connect();
  console.log('Connected to Chat Postgres!');
  const tables = await client.query('SELECT table_name FROM information_schema.tables WHERE table_schema = \'public\';');
  console.log('Chat tables:', tables.rows.map(r => r.table_name));

  const columns = await client.query('SELECT column_name FROM information_schema.columns WHERE table_name = \'message_reads\';');
  console.log('message_reads columns:', columns.rows.map(r => r.column_name));

  const convColumns = await client.query('SELECT column_name FROM information_schema.columns WHERE table_name = \'conversations\';');
  console.log('conversations columns:', convColumns.rows.map(r => r.column_name));

  const convMemberColumns = await client.query('SELECT column_name FROM information_schema.columns WHERE table_name = \'conversation_members\';');
  console.log('conversation_members columns:', convMemberColumns.rows.map(r => r.column_name));

  await client.end();
}

run().catch(console.error);
