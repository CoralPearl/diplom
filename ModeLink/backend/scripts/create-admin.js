require('dotenv').config();

const bcrypt = require('bcryptjs');
const { prisma } = require('../src/services/db');

async function main() {
  const email = process.argv[2];
  const password = process.argv[3];

  if (!email || !password) {
    console.log('Usage: node scripts/create-admin.js <email> <password>');
    process.exit(1);
  }

  const passwordHash = await bcrypt.hash(password, 10);

  const user = await prisma.user.upsert({
    where: { email: email.toLowerCase() },
    update: {
      passwordHash,
      role: 'admin',
      isVerified: true,
    },
    create: {
      email: email.toLowerCase(),
      passwordHash,
      role: 'admin',
      isVerified: true,
    },
  });

  console.log('Admin user ready:', { id: user.id, email: user.email, role: user.role });
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
