const fs = require('fs');
const path = require('path');

const p1 = path.resolve(__dirname, '../../CodeXa/codexa-portfolio/src/app/api/chat/conversations/[id]/messages/route.ts');
let c1 = fs.readFileSync(p1, 'utf8');
c1 = c1.replace(
  'const senderAvatarUrl = user.profileMediaUrl || user.profile?.mediaUrl || null;',
  'const senderAvatarUrl = (user as any).profileMediaUrl || (user as any).profile?.mediaUrl || null;'
);
fs.writeFileSync(p1, c1, 'utf8');

const p2 = path.resolve(__dirname, '../../CodeXa/codexa-portfolio/src/app/api/chat/messages/route.ts');
let c2 = fs.readFileSync(p2, 'utf8');
c2 = c2.replace(
  'const senderAvatarUrl = user.profileMediaUrl || user.profile?.mediaUrl || null;',
  'const senderAvatarUrl = (user as any).profileMediaUrl || (user as any).profile?.mediaUrl || null;'
);
fs.writeFileSync(p2, c2, 'utf8');

console.log('Fixed senderAvatarUrl casting in both routes.');
