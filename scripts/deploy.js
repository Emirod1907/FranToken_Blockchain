const { ethers, network } = require("hardhat");

/**
 * Despliega la suite ERC-3643 para una franquicia y los contratos del fideicomiso:
 *   IdentityRegistry -> FranchiseCompliance -> FranchiseToken
 *   FranchiseAgreement (CONTRATO 1) -> OperatingAgreement (CONTRATO 2)
 *
 * Los contratos 1 y 2 quedan en borrador: cada parte debe firmar (`sign`) y luego `activate`.
 *
 * Variables de entorno opcionales:
 *   PAYMENT_TOKEN  dirección del stablecoin de pago (USDC, etc.). En redes locales se
 *                  despliega un MockStablecoin si no se indica.
 *   FRANCHISOR, TRUST, OPERATOR  wallets del franquiciante, el fideicomiso y la operadora.
 *                  En redes locales se usan cuentas de prueba si no se indican.
 */
async function main() {
  const [deployer, ...testAccounts] = await ethers.getSigners();
  const isLocal = ["hardhat", "localhost"].includes(network.name);
  console.log(`Red: ${network.name}`);
  console.log(`Deployer: ${deployer.address}`);

  const party = (envName, index) => {
    if (process.env[envName]) return process.env[envName];
    if (!isLocal) throw new Error(`Define ${envName} con la wallet correspondiente en esta red`);
    return testAccounts[index].address;
  };
  const franchisor = party("FRANCHISOR", 0);
  const trust = party("TRUST", 1);
  const operator = party("OPERATOR", 2);

  let paymentToken = process.env.PAYMENT_TOKEN;
  if (!paymentToken) {
    if (!isLocal) {
      throw new Error("Define PAYMENT_TOKEN con la dirección del stablecoin en esta red");
    }
    const mock = await ethers.deployContract("MockStablecoin");
    await mock.waitForDeployment();
    paymentToken = await mock.getAddress();
    console.log(`MockStablecoin: ${paymentToken}`);
  }

  const registry = await ethers.deployContract("IdentityRegistry", [deployer.address]);
  await registry.waitForDeployment();
  console.log(`IdentityRegistry: ${await registry.getAddress()}`);

  const compliance = await ethers.deployContract("FranchiseCompliance", [deployer.address]);
  await compliance.waitForDeployment();
  console.log(`FranchiseCompliance: ${await compliance.getAddress()}`);

  const token = await ethers.deployContract("FranchiseToken", [
    "Cafe Central Polanco", // nombre
    "CCPOL", // símbolo
    0, // decimales: participaciones enteras
    10_000, // máximo de participaciones
    await registry.getAddress(),
    await compliance.getAddress(),
    paymentToken,
    ethers.ZeroAddress, // ONCHAINID del emisor (opcional)
    deployer.address,
  ]);
  await token.waitForDeployment();
  const tokenAddress = await token.getAddress();
  console.log(`FranchiseToken: ${tokenAddress}`);

  // Roles: el deployer opera como agente; el token necesita ser agente del registry
  // para poder ejecutar recoveryAddress.
  await (await registry.addAgent(deployer.address)).wait();
  await (await registry.addAgent(tokenAddress)).wait();
  await (await token.addAgent(deployer.address)).wait();

  await (
    await token.setFranchiseInfo({
      franchiseName: "Cafe Central - Sucursal Polanco",
      brand: "Cafe Central",
      location: "Ciudad de Mexico, MX",
      legalDocumentURI: "ipfs://REEMPLAZAR_CID_DEL_CONTRATO",
      legalDocumentHash: ethers.ZeroHash,
      valuation: ethers.parseUnits("500000", 6),
    })
  ).wait();

  // Reglas de ejemplo
  await (await compliance.setMaxHolders(150)).wait();
  await (await compliance.setMaxBalancePerInvestor(2_000)).wait();

  // ---- Contratos del fideicomiso (valores de ejemplo) ----
  const USDC = (n) => ethers.parseUnits(String(n), 6);
  const DAY = 24 * 60 * 60;
  const MONTH = 30 * DAY;
  const YEAR = 12 * MONTH;

  const franchise = await ethers.deployContract("FranchiseAgreement", [
    {
      partyA: franchisor,
      partyB: trust,
      paymentToken,
      duration: 5 * YEAR,
      periodLength: MONTH,
      curePeriod: 15 * DAY,
      renewalTerm: 5 * YEAR,
      documentURI: "ipfs://REEMPLAZAR_CID_CONTRATO_FRANQUICIA",
      documentHash: ethers.ZeroHash,
    },
    {
      brand: {
        name: "Cafe Central",
        trademarkRegistration: "REEMPLAZAR_REGISTRO_MARCA",
        brandManualURI: "ipfs://REEMPLAZAR_CID_MANUAL_MARCA",
        brandManualHash: ethers.ZeroHash,
      },
      territory: { description: "Polanco, Ciudad de Mexico", exclusive: true, zones: [] },
      royalty: {
        entryFee: USDC(20_000),
        royaltyBps: 500,
        advertisingFeeBps: 200,
        minimumRoyalty: USDC(1_000),
        paymentGracePeriod: 10 * DAY,
      },
      knowHow: { uri: "ipfs://REEMPLAZAR_CID_MANUAL_OPERATIVO", hash: ethers.ZeroHash, version: 0, updatedAt: 0 },
      standards: { uri: "ipfs://REEMPLAZAR_CID_ESTANDARES", hash: ethers.ZeroHash, version: 0, updatedAt: 0 },
      minimumInspectionScore: 70,
    },
  ]);
  await franchise.waitForDeployment();
  const franchiseAddress = await franchise.getAddress();
  console.log(`FranchiseAgreement (contrato 1): ${franchiseAddress}`);

  const operating = await ethers.deployContract("OperatingAgreement", [
    {
      partyA: trust,
      partyB: operator,
      paymentToken,
      duration: 2 * YEAR,
      periodLength: MONTH,
      curePeriod: 15 * DAY,
      renewalTerm: YEAR,
      documentURI: "ipfs://REEMPLAZAR_CID_CONTRATO_OPERACION",
      documentHash: ethers.ZeroHash,
    },
    {
      store: { name: "Cafe Central - Sucursal Polanco", location: "Ciudad de Mexico, MX" },
      fees: { fixedFee: USDC(2_000), successFeeBps: 1_000, reviewPeriod: 7 * DAY, paymentGracePeriod: 5 * DAY },
      kpis: { minGrossSales: USDC(30_000), maxCostRatioBps: 8_500, maxConsecutiveMisses: 3 },
      controls: { reportDeadline: 10 * DAY, purchaseApprovalThreshold: USDC(5_000) },
      franchiseAgreement: franchiseAddress,
    },
  ]);
  await operating.waitForDeployment();
  const operatingAddress = await operating.getAddress();
  console.log(`OperatingAgreement (contrato 2): ${operatingAddress}`);

  // Regalías y honorarios se pagan antes que los inversores.
  await (await token.addSeniorObligation(franchiseAddress)).wait();
  await (await token.addSeniorObligation(operatingAddress)).wait();

  console.log("Despliegue completado.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
