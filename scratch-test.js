const { PrismaClient } = require('g:/AntiGravity IDE/CodeXa/codexa-portfolio/node_modules/@prisma/client');
require('g:/AntiGravity IDE/CodeXa/codexa-portfolio/node_modules/dotenv').config({ path: 'g:/AntiGravity IDE/CodeXa/codexa-portfolio/.env' });

const prisma = new PrismaClient();

async function main() {
  const leaves = await prisma.leaveRequest.findMany({
    include: {
      user: {
        select: {
          id: true,
          fullName: true,
          username: true,
          email: true,
          role: true,
          profileMediaUrl: true,
          employmentProfile: true,
        }
      }
    }
  });
  console.log("LEAVE REQUESTS COUNT:", leaves.length);
  if (leaves.length > 0) {
    console.log("LEAVES SAMPLE:", JSON.stringify(leaves.slice(0, 3), null, 2));
  }
}

main().catch(console.error).finally(() => prisma.$disconnect());
