const { Client } = require('../../CodeXa/codexa-portfolio/node_modules/pg');
const fs = require('fs');
const path = require('path');

async function migrate() {
  // Try pooler first
  const connectionString = 'postgresql://postgres.dadjehjqbcvynbahiukn:HLJQ88.-ycz%2FNe%25@aws-0-ap-south-1.pooler.supabase.com:6543/postgres';
  console.log('Connecting to Chat Supabase database...');
  
  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false },
  });

  try {
    await client.connect();
    console.log('Connected successfully!');

    const sqlPath = path.resolve(__dirname, '../supabase-chat/migrations/001_create_chat_schema.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    console.log('Executing migration 001_create_chat_schema.sql...');
    await client.query(sql);
    console.log('✓ Migration executed successfully! All tables, indexes, RLS, and Realtime publications are created.');
  } catch (err) {
    console.error('Migration error:', err.message);
  } finally {
    await client.end();
  }
}

migrate();
