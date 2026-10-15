const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const schemaPath = path.resolve(__dirname, '../../CodeXa/codexa-portfolio/prisma/schema.prisma');
let schema = fs.readFileSync(schemaPath, 'utf8');

if (!schema.includes('activeConversationId')) {
  schema = schema.replace(
    '  lastActive  DateTime  @default(now())\n',
    '  lastActive  DateTime  @default(now())\n  activeConversationId  String?\n  activeConversationAt  DateTime?\n'
  );
  fs.writeFileSync(schemaPath, schema, 'utf8');
  console.log('Updated schema.prisma with active conversation fields.');
} else {
  console.log('schema.prisma already has active conversation fields.');
}

console.log('Running prisma generate...');
const out = execSync('npx prisma generate', { cwd: path.resolve(__dirname, '../../CodeXa/codexa-portfolio') }).toString();
console.log(out);
