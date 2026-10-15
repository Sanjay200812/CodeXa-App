const { Client } = require('G:/AntiGravity IDE/CodeXa/codexa-portfolio/node_modules/pg');
const fs = require('fs');

const env = fs.readFileSync('G:/AntiGravity IDE/CodeXa/codexa-portfolio/.env', 'utf8');
const dbUrlMatch = env.match(/CHAT_SUPABASE_DB_URL=["']?([^"'\r\n]+)/);

const connectionString = dbUrlMatch ? dbUrlMatch[1].trim() : '';
console.log('Connecting to Chat Postgres DB via pooler:', connectionString.split('@')[1]);

const client = new Client({
  connectionString,
  ssl: { rejectUnauthorized: false }
});

async function run() {
  await client.connect();
  console.log('Connected! Modifying check constraint...');
  
  await client.query(`
    ALTER TABLE public.messages 
    DROP CONSTRAINT IF EXISTS messages_message_type_check;
  `);

  await client.query(`
    ALTER TABLE public.messages 
    ADD CONSTRAINT messages_message_type_check 
    CHECK (message_type IN ('TEXT', 'IMAGE', 'FILE', 'SYSTEM', 'STICKER', 'VIDEO', 'AUDIO', 'VIEW_ONCE_IMAGE', 'VIEW_ONCE_VIDEO'));
  `);

  await client.query(`
    ALTER TABLE public.messages 
    ADD COLUMN IF NOT EXISTS is_view_once BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS view_once_consumed BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS view_once_opened_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS view_once_consumed_at TIMESTAMPTZ;
  `);

  await client.query(`
    CREATE TABLE IF NOT EXISTS public.message_view_once_sessions (
      id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
      message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
      viewer_core_user_id TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'AVAILABLE',
      opened_at TIMESTAMPTZ,
      consumed_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ DEFAULT now(),
      CONSTRAINT uq_message_viewer UNIQUE(message_id, viewer_core_user_id)
    );
    CREATE INDEX IF NOT EXISTS idx_vo_sessions_msg ON public.message_view_once_sessions(message_id);
    CREATE INDEX IF NOT EXISTS idx_vo_sessions_user ON public.message_view_once_sessions(viewer_core_user_id);
  `);

  console.log('Successfully updated messages constraint for VIEW_ONCE and created sessions table!');
  await client.end();
}

run().catch(e => {
  console.error('Migration error:', e);
  process.exit(1);
});
