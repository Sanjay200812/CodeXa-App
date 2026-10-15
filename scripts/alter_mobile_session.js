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
  console.log('Connected to Core Postgres!');

  await client.query(`
    ALTER TABLE "MobileSession"
    ADD COLUMN IF NOT EXISTS "activeConversationId" TEXT,
    ADD COLUMN IF NOT EXISTS "activeConversationAt" TIMESTAMPTZ;
  `);

  console.log('Successfully altered MobileSession with activeConversationId and activeConversationAt!');

  const res = await client.query('SELECT column_name FROM information_schema.columns WHERE table_name = \'MobileSession\';');
  console.log('MobileSession columns now:', res.rows.map(r => r.column_name));

  await client.end();
}

run().catch(console.error);
