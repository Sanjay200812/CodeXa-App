const { PrismaClient } = require('G:/AntiGravity IDE/CodeXa/codexa-portfolio/node_modules/@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const users = await prisma.user.findMany({
    where: {
      isActive: true,
      OR: [
        { fullName: { contains: 'sanju', mode: 'insensitive' } },
        { username: { contains: 'sanju', mode: 'insensitive' } },
      ],
    },
    select: { id: true, username: true, fullName: true, role: true, email: true }
  });
  console.log('Search for sanju found:', JSON.stringify(users, null, 2));

  // Also check projects
  const projects = await prisma.project.findMany({
    take: 2,
    select: { id: true, title: true, category: true }
  });
  console.log('Sample projects:', JSON.stringify(projects, null, 2));

  await prisma.$disconnect();
}

main().catch(console.error);
