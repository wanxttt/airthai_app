import { seedRoles } from './roles.seed';

// Optional import when @prisma/client is installed in environment
let PrismaClient: any;
try {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  PrismaClient = require('@prisma/client').PrismaClient;
} catch {
  // Fallback for pre-build validation environments
  PrismaClient = class MockPrismaClient {};
}

async function main() {
  const prisma = new PrismaClient();

  if (typeof prisma.$connect !== 'function') {
    // eslint-disable-next-line no-console
    console.log('PrismaClient not yet generated. Seed file is ready for execution after client generation.');
    return;
  }

  try {
    await prisma.$connect();
    // eslint-disable-next-line no-console
    console.log('Seeding default system roles and permissions...');
    await seedRoles(prisma);
    // eslint-disable-next-line no-console
    console.log('Database seeding completed successfully.');
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('Seeding failed:', error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

if (require.main === module) {
  main();
}

export { main as runSeed };
