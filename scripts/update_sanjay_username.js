const path = require('path');
const { PrismaClient } = require(path.resolve(__dirname, '../../CodeXa/codexa-portfolio/node_modules/@prisma/client'));
const prisma = new PrismaClient();

async function main() {
  const targetUserId = 'cmuw8zizo000h12t76attfbro';

  // 1. Double check current user
  const user = await prisma.user.findUnique({
    where: { id: targetUserId },
  });

  if (!user) {
    throw new Error('Target user cmuw8zizo000h12t76attfbro not found');
  }

  console.log(`Current user: ${user.fullName} (@${user.username}) [${user.email}]`);

  // 2. Check if 'sanju' is already taken by anyone else
  const existing = await prisma.user.findFirst({
    where: {
      username: { equals: 'sanju', mode: 'insensitive' },
      NOT: { id: targetUserId },
    },
  });

  if (existing) {
    throw new Error(`Username "sanju" is already taken by user ${existing.id}`);
  }

  // 3. Update username to 'sanju'
  const updated = await prisma.user.update({
    where: { id: targetUserId },
    data: { username: 'sanju' },
  });

  console.log(`SUCCESS: Updated user ${updated.id} username to: @${updated.username}`);

  // 4. Invalidate/update any cached mobile sessions if necessary
  console.log('User mutation verified in Core DB.');
}

main().catch(console.error).finally(() => prisma.$disconnect());
