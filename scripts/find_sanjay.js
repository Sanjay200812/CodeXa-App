const path = require('path');
const { PrismaClient } = require(path.resolve(__dirname, '../../CodeXa/codexa-portfolio/node_modules/@prisma/client'));
const prisma = new PrismaClient();

async function main() {
  const users = await prisma.user.findMany({
    where: {
      OR: [
        { fullName: { contains: 'Sanjay', mode: 'insensitive' } },
        { username: { contains: 'sanjay', mode: 'insensitive' } },
        { username: { contains: 'sanju', mode: 'insensitive' } },
        { email: { contains: 'sanjay', mode: 'insensitive' } },
        { email: { contains: 'sanju', mode: 'insensitive' } }
      ]
    },
    select: {
      id: true,
      email: true,
      username: true,
      fullName: true,
      role: true,
      isActive: true,
      createdAt: true,
      profile: {
        select: {
          displayName: true,
          bio: true,
        }
      },
      employmentProfile: {
        select: {
          employeeId: true,
          designation: true,
          department: true,
        }
      }
    }
  });

  console.log('--- FOUND USERS ---');
  console.log(JSON.stringify(users, null, 2));

  // Check if username 'sanju' exists
  const sanjuUser = await prisma.user.findFirst({
    where: { username: { equals: 'sanju', mode: 'insensitive' } }
  });
  console.log('Is "sanju" taken?', !!sanjuUser, sanjuUser?.id);
}

main().catch(console.error).finally(() => prisma.$disconnect());
