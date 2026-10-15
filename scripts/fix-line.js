const fs = require('fs');
const path = require('path');

const file = path.resolve(__dirname, '../../CodeXa/codexa-portfolio/src/app/api/chat/conversations/[id]/messages/route.ts');
let content = fs.readFileSync(file, 'utf8');
content = content.replace('title: `Message from ${user.name}`,', 'title: `Message from ${user.username || "Colleague"}`,');
fs.writeFileSync(file, content, 'utf8');
console.log('Fixed line 122 successfully');
