const { PrismaClient } = require('g:/AntiGravity IDE/CodeXa/codexa-portfolio/node_modules/@prisma/client');
require('g:/AntiGravity IDE/CodeXa/codexa-portfolio/node_modules/dotenv').config({ path: 'g:/AntiGravity IDE/CodeXa/codexa-portfolio/.env' });
const prisma = new PrismaClient();

async function main() {
  const users = await prisma.user.findMany({
    select: {
      id: true,
      username: true,
      fullName: true,
      role: true,
      profileMediaUrl: true,
      profile: {
        select: {
          mediaUrl: true,
          profileMediaUrl: true,
          displayName: true,
        }
      }
    }
  });

  console.log('Total users:', users.length);
  const withImages = users.filter(u => u.profileMediaUrl || u.profile?.profileMediaUrl || u.profile?.mediaUrl);
  console.log('Users with images:', withImages.length);
  for (const u of users) {
    if (u.profileMediaUrl || u.profile?.profileMediaUrl || u.profile?.mediaUrl) {
      console.log(`[${u.username}] User.profileMediaUrl: ${u.profileMediaUrl} | Profile.profileMediaUrl: ${u.profile?.profileMediaUrl} | Profile.mediaUrl: ${u.profile?.mediaUrl}`);
    } else {
      console.log(`[${u.username}] NO IMAGE`);
    }
  }
}

main().catch(console.error).finally(() => prisma.$disconnect());
