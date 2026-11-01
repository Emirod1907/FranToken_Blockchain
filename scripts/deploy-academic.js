const { ethers, network } = require('hardhat');
const { mkdir, writeFile } = require('node:fs/promises');
const { randomUUID } = require('node:crypto');
const path = require('node:path');

async function deployAcademic({ writeManifest = true } = {}) {
  if (!['hardhat', 'localhost'].includes(network.name) || (await ethers.provider.getNetwork()).chainId !== 31337n) {
    throw new Error('La demo académica solo admite Hardhat local (31337)');
  }
  const [admin, trust, platform, verifier, ...investors] = await ethers.getSigners();
  const payment = await ethers.deployContract('MockStablecoin');
  const registry = await ethers.deployContract('IdentityRegistry', [admin.address]);
  await registry.addAgent(admin.address);
  const services = await ethers.deployContract('PlatformServicesAgreement', [trust.address, platform.address, '0x555344', 2, 50, ethers.id('DEMO: C3 académico, 0.5% ilustrativo')]);
  await services.connect(trust).sign();
  await services.connect(platform).sign();
  const projects = [];
  const examples = [['mcdonalds', "McDonald's · unidad académica", 'MCD'], ['burger-king', 'Burger King · unidad académica', 'BK'], ['havanna', 'Havanna · unidad académica', 'HAV'], ['pizza-hut', 'Pizza Hut · unidad académica', 'PIZZA']];
  for (const [id, name, symbol] of examples) {
    const compliance = await ethers.deployContract('FranchiseCompliance', [admin.address]);
    // 1000 unidades es disponibilidad ficticia de la presentación, configurable en este fixture.
    const token = await ethers.deployContract('AcademicFranchiseToken', [name, symbol, 1000, await registry.getAddress(), await compliance.getAddress(), await payment.getAddress(), admin.address]);
    const investment = await ethers.deployContract('InvestmentAgreement', [trust.address, await token.getAddress(), await services.getAddress(), verifier.address, 1000, ethers.id(`DEMO ${id}: ingresos variables, prorrata al distribuir, sin transferencias`)]);
    await token.addAgent(await investment.getAddress());
    await token.setIssuanceController(await investment.getAddress());
    await token.addAgent(admin.address);
    await token.setProjectStatus(1);
    projects.push({ id, name, token: await token.getAddress(), investment: await investment.getAddress() });
  }
  // Identidades manuales de demostración: nunca KYC real ni datos personales.
  for (const investor of [admin, trust, platform, verifier, ...investors]) {
    await registry.registerIdentity(investor.address, investor.address, 32);
  }
  await payment.mint(admin.address, ethers.parseUnits('1000000', 6));
  const manifest = { version: 1, deploymentId: randomUUID(), chainId: 31337, fromBlock: 0, admin: admin.address, verifier: verifier.address, registry: await registry.getAddress(), paymentToken: await payment.getAddress(), projects };
  if (writeManifest) {
    const target = path.join(__dirname, '../deployments/academic-local.json');
    await mkdir(path.dirname(target), { recursive: true });
    await writeFile(target, JSON.stringify(manifest, null, 2) + '\n');
    console.log(`Demo desplegada. Manifiesto sin claves: ${target}`);
    console.log('Franquicias publicadas; el administrador debe iniciar operación antes de distribuir.');
  }
  return manifest;
}
module.exports = { deployAcademic };
if (require.main === module) deployAcademic().catch(error => { console.error(error); process.exitCode = 1; });
