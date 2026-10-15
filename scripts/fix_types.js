const fs = require('fs');
const path = require('path');

const portfolioDir = path.resolve('..', 'CodeXa', 'codexa-portfolio');

// Fix analyze-payment-proof.ts comment syntax
const ocrPath = path.join(portfolioDir, 'src', 'lib', 'payments', 'analyze-payment-proof.ts');
let ocrContent = fs.readFileSync(ocrPath, 'utf8');
ocrContent = ocrContent.replace(
  `/**\n// In-memory cache for recent OCR extractions`,
  `// In-memory cache for recent OCR extractions`
);
fs.writeFileSync(ocrPath, ocrContent, 'utf8');
console.log('Fixed analyze-payment-proof.ts comment');

// Fix messages/route.ts types
const messagesRoutePath = path.join(portfolioDir, 'src', 'app', 'api', 'chat', 'messages', 'route.ts');
let msgContent = fs.readFileSync(messagesRoutePath, 'utf8');

// Fix senderIds mapping
msgContent = msgContent.replace(
  `const senderIds = Array.from(new Set((messages || []).map((m: any) => m.sender_core_user_id)));`,
  `const senderIds: string[] = Array.from(new Set((messages || []).map((m: any) => String(m.sender_core_user_id))));`
);
// Fix user.fullName to user.username
msgContent = msgContent.replace(
  `title: \`Message from \${user.fullName || user.username || "Colleague"}\`,`,
  `title: \`Message from \${user.username || "Colleague"}\`,`
);
msgContent = msgContent.replace(
  `title: user.fullName || user.username || "CodeXa Message",`,
  `title: user.username || "CodeXa Message",`
);

fs.writeFileSync(messagesRoutePath, msgContent, 'utf8');
console.log('Fixed messages/route.ts types');
