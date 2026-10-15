const fs = require('fs');
const path = require('path');

const envPath = path.resolve(__dirname, '../../CodeXa/codexa-portfolio/.env');

if (fs.existsSync(envPath)) {
  const content = fs.readFileSync(envPath, 'utf8');
  if (!content.includes('CHAT_SUPABASE_URL')) {
    const chatSection = `

# ============================================================
# CODEXA CHAT SUPABASE — SECOND PROJECT
# ============================================================
CHAT_SUPABASE_URL="https://[YOUR_CHAT_PROJECT_REF].supabase.co"
NEXT_PUBLIC_CHAT_SUPABASE_URL="https://[YOUR_CHAT_PROJECT_REF].supabase.co"
CHAT_SUPABASE_PUBLISHABLE_KEY="your_chat_supabase_anon_key_here"
NEXT_PUBLIC_CHAT_SUPABASE_PUBLISHABLE_KEY="your_chat_supabase_anon_key_here"
CHAT_SUPABASE_SECRET_KEY="your_chat_supabase_service_role_key_here"
CHAT_SUPABASE_DB_URL="postgresql://postgres.[CHAT_REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres?pgbouncer=true"
CHAT_SUPABASE_DIRECT_URL="postgresql://postgres.[CHAT_REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:5432/postgres"
CHAT_SUPABASE_STORAGE_BUCKET="chat-private"
CHAT_SUPABASE_REALTIME_ENABLED="true"
CHAT_JWT_SECRET="your_custom_jwt_signing_secret_min_32_characters_here"
CHAT_JWT_ISSUER="codexa-chat"
CHAT_JWT_AUDIENCE="codexa-mobile"
`;
    fs.appendFileSync(envPath, chatSection, 'utf8');
    console.log('Successfully appended Chat Supabase section to backend .env');
  } else {
    console.log('Chat Supabase variables are already present in backend .env');
  }
} else {
  console.log('Backend .env does not exist at:', envPath);
}
