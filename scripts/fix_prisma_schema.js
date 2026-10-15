const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const schemaPath = path.resolve(__dirname, '../../CodeXa/codexa-portfolio/prisma/schema.prisma');
let lines = fs.readFileSync(schemaPath, 'utf8').split('\n');

const modelIdx = lines.findIndex(l => l.trim() === 'model MobileSession {');
if (modelIdx !== -1) {
  // Find lastActive in this model
  const lastActiveIdx = lines.findIndex((l, i) => i > modelIdx && l.includes('lastActive'));
  if (lastActiveIdx !== -1) {
    lines.splice(lastActiveIdx + 1, 0,
      '  activeConversationId  String?',
      '  activeConversationAt  DateTime?'
    );
    fs.writeFileSync(schemaPath, lines.join('\n'), 'utf8');
    console.log('Inserted active conversation fields at line', lastActiveIdx + 2);
  }
}

const out = execSync('npx prisma generate', { cwd: path.resolve(__dirname, '../../CodeXa/codexa-portfolio') }).toString();
console.log(out);
