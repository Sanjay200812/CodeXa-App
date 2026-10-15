const fs = require('fs');
const file = 'G:/AntiGravity IDE/CodeXa/codexa-portfolio/src/app/api/chat/messages/route.ts';
let code = fs.readFileSync(file, 'utf8');

const target = 'let messageType = body.messageType || "TEXT";';
const replacement = `let messageType = body.messageType || "TEXT";
    const stickerId = body.stickerId;
    const catalogVersion = body.catalogVersion;
    if (stickerId || messageType === "STICKER") {
      messageType = "STICKER";
      if (stickerId) text = stickerId;
    }`;

if (code.includes(target) && !code.includes('const stickerId = body.stickerId;')) {
  code = code.replace(target, replacement);
}

code = code.replace(/const pushBody = messageType === [^\r\n]+;/, 'const pushBody = messageType === "STICKER" ? "🎨 Sent a sticker" : messageType === "IMAGE" ? "📷 Sent a photo" : (text || "New message").slice(0, 100);');

fs.writeFileSync(file, code);
console.log('Successfully updated backend chat route for STICKER!');
