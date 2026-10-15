const { createClient } = require('G:/AntiGravity IDE/CodeXa/codexa-portfolio/node_modules/@supabase/supabase-js');
const fs = require('fs');

const env = fs.readFileSync('G:/AntiGravity IDE/CodeXa/codexa-portfolio/.env', 'utf8');
const urlMatch = env.match(/CHAT_SUPABASE_URL=["']?([^"'\r\n]+)/);
const keyMatch = env.match(/CHAT_SUPABASE_SECRET_KEY=["']?([^"'\r\n]+)/);

const supabaseUrl = urlMatch ? urlMatch[1].trim() : '';
const supabaseKey = keyMatch ? keyMatch[1].trim() : '';

const supabase = createClient(supabaseUrl, supabaseKey);

async function testStickerType() {
  const { data: conv } = await supabase.from('conversations').select('id').limit(1).single();
  if (!conv) {
    console.log('No conversations found');
    return;
  }
  console.log('Found conv:', conv.id);

  // Try dry insert or inspect table constraints
  const testId = 'test-client-' + Date.now();
  const { data, error } = await supabase.from('messages').insert({
    conversation_id: conv.id,
    sender_core_user_id: 'sys-test',
    client_message_id: testId,
    message_type: 'STICKER',
    text: '00170139edda097c887f0636ca7a5d1b5c5ece7900a3db38801651f315f69f11'
  }).select();

  if (error) {
    console.log('Insert STICKER result error:', error);
  } else {
    console.log('Successfully inserted STICKER message:', data);
    // clean it up
    await supabase.from('messages').delete().eq('client_message_id', testId);
    console.log('Cleaned up test message');
  }
}

testStickerType();
