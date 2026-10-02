const { ethers, network } = require("hardhat");

/**
 * Despliega la suite ERC-3643 para una franquicia:
 *   IdentityRegistry -> FranchiseCompliance -> FranchiseToken
 *
 * Variables de entorno opcionales:
 *   PAYMENT_TOKEN  dirección del stablecoin de pago (USDC, etc.). En redes locales se
 *                  despliega un MockStablecoin si no se indica.
 */
async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`Red: ${network.name}`);
  console.log(`Deployer: ${deployer.address}`);

  let paymentToken = process.env.PAYMENT_TOKEN;
  if (!paymentToken) {
    if (!["hardhat", "localhost"].includes(network.name)) {
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

  console.log("Despliegue completado.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
