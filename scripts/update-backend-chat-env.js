const fs = require('fs');
const path = require('path');

const file = path.resolve(__dirname, '../../CodeXa/codexa-portfolio/.env');
if (fs.existsSync(file)) {
  let content = fs.readFileSync(file, 'utf8');

  content = content.replace(/CHAT_SUPABASE_URL=".*"/, 'CHAT_SUPABASE_URL="https://dadjehjqbcvynbahiukn.supabase.co"');
  content = content.replace(/NEXT_PUBLIC_CHAT_SUPABASE_URL=".*"/, 'NEXT_PUBLIC_CHAT_SUPABASE_URL="https://dadjehjqbcvynbahiukn.supabase.co"');
  content = content.replace(/CHAT_SUPABASE_PUBLISHABLE_KEY=".*"/, 'CHAT_SUPABASE_PUBLISHABLE_KEY="sb_publishable_FyPlpqEnxRFrReo1nLymNA_1Z1NJa25"');
  content = content.replace(/NEXT_PUBLIC_CHAT_SUPABASE_PUBLISHABLE_KEY=".*"/, 'NEXT_PUBLIC_CHAT_SUPABASE_PUBLISHABLE_KEY="sb_publishable_FyPlpqEnxRFrReo1nLymNA_1Z1NJa25"');
  content = content.replace(/CHAT_SUPABASE_SECRET_KEY=".*"/, 'CHAT_SUPABASE_SECRET_KEY="sb_secret_QZHjjX7MhtXK4ghN3Gxv_A_VyBIql6U"');
  content = content.replace(/CHAT_SUPABASE_DB_URL=".*"/, 'CHAT_SUPABASE_DB_URL="postgresql://postgres.dadjehjqbcvynbahiukn:HLJQ88.-ycz%2FNe%25@aws-0-ap-south-1.pooler.supabase.com:6543/postgres?pgbouncer=true"');
  content = content.replace(/CHAT_SUPABASE_DIRECT_URL=".*"/, 'CHAT_SUPABASE_DIRECT_URL="postgresql://postgres:HLJQ88.-ycz%2FNe%25@db.dadjehjqbcvynbahiukn.supabase.co:5432/postgres"');

  fs.writeFileSync(file, content, 'utf8');
  console.log('Successfully updated Chat Supabase credentials in backend .env');
} else {
  console.log('Backend .env not found');
}
