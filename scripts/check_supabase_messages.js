const { createClient } = require('G:/AntiGravity IDE/CodeXa/codexa-portfolio/node_modules/@supabase/supabase-js');
const fs = require('fs');

const env = fs.readFileSync('G:/AntiGravity IDE/CodeXa/codexa-portfolio/.env', 'utf8');
const urlMatch = env.match(/CHAT_SUPABASE_URL=["']?([^"'\r\n]+)/);
const keyMatch = env.match(/CHAT_SUPABASE_SECRET_KEY=["']?([^"'\r\n]+)/);

const supabaseUrl = urlMatch ? urlMatch[1].trim() : '';
const supabaseKey = keyMatch ? keyMatch[1].trim() : '';

console.log('Connecting to Chat Supabase at:', supabaseUrl);
const supabase = createClient(supabaseUrl, supabaseKey);

async function test() {
  const { data, error } = await supabase.from('messages').select('*').limit(3);
  if (error) {
    console.error('Supabase query error:', error);
  } else {
    console.log('Sample message record count:', data?.length);
    if (data && data[0]) {
      console.log('Keys:', Object.keys(data[0]));
      console.log('Sample message types in DB:', data.map(d => ({ type: d.message_type, text: d.text })));
    }
  }
}

test();
