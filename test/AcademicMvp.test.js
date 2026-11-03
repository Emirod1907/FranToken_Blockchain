const { expect } = require('chai');
const { ethers } = require('hardhat');
const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');

async function fixture() {
  const [admin, platform, verifier, alice, bob, outsider] = await ethers.getSigners();
  const payment = await ethers.deployContract('MockStablecoin');
  const registry = await ethers.deployContract('IdentityRegistry', [admin.address]);
  const compliance = await ethers.deployContract('FranchiseCompliance', [admin.address]);
  const token = await ethers.deployContract('AcademicFranchiseToken', ['Demo', 'DEMO', 1000, await registry.getAddress(), await compliance.getAddress(), await payment.getAddress(), admin.address]);
  const services = await ethers.deployContract('PlatformServicesAgreement', [admin.address, platform.address, '0x555344', 2, 50, ethers.id('demo services')]);
  await services.sign(); await services.connect(platform).sign();
  const investment = await ethers.deployContract('InvestmentAgreement', [admin.address, await token.getAddress(), await services.getAddress(), verifier.address, 1000, ethers.id('demo rights')]);
  await token.addAgent(await investment.getAddress()); await token.setIssuanceController(await investment.getAddress()); await token.addAgent(admin.address);
  await registry.addAgent(admin.address);
  for (const user of [alice, bob]) {
    await registry.registerIdentity(user.address, user.address, 32);
    await investment.connect(user).acceptTerms();
  }
  await payment.mint(admin.address, 1000000000n); await payment.approve(await token.getAddress(), ethers.MaxUint256);
  const issue = (user, units, ref = 'purchase') => investment.connect(verifier).issueAfterPayment(ethers.id(ref), ethers.id('pay-'+ref), user.address, units, BigInt(units)*1000n, ethers.id('simulated evidence'));
  return { admin, alice, bob, outsider, verifier, token, investment, payment, registry, issue };
}

describe('MVP académico', function () {
  it('solo publica/administra el owner y C4 emite una vez por compra', async function () {
    const { token, outsider, alice, investment, issue } = await loadFixture(fixture);
    await expect(issue(alice, 2)).to.be.revertedWithCustomError(token, 'ProjectNotPurchasable');
    await expect(token.connect(outsider).setProjectStatus(1)).to.be.revertedWithCustomError(token, 'OwnableUnauthorizedAccount');
    await token.setProjectStatus(1); await issue(alice, 2);
    expect(await token.balanceOf(alice.address)).to.equal(2);
    await expect(issue(alice, 2)).to.be.revertedWithCustomError(investment, 'PurchaseAlreadyIssued');
    await expect(token.mint(alice.address, 1)).to.be.revertedWithCustomError(token, 'UnauthorizedIssuer');
  });
  it('rechaza importe incorrecto, falta de términos, KYC, congelamiento y pausa sin consumir compra', async function () {
    const { token, investment, verifier, outsider, alice, registry, issue } = await loadFixture(fixture);
    await token.setProjectStatus(1);
    await expect(investment.connect(verifier).issueAfterPayment(ethers.id('bad'), ethers.id('badpay'), alice.address, 1, 999, ethers.id('e'))).to.be.revertedWithCustomError(investment,'AmountMismatch');
    await expect(issue(outsider,1,'terms')).to.be.revertedWithCustomError(investment,'TermsNotAccepted');
    await investment.connect(outsider).acceptTerms();
    await expect(issue(outsider,1,'kyc')).to.be.revertedWithCustomError(token,'RecipientNotVerified');
    await token.setAddressFrozen(alice.address,true);
    await expect(issue(alice,1)).to.be.revertedWithCustomError(token,'AddressIsFrozen');
    await token.setAddressFrozen(alice.address,false); await token.pause();
    await expect(issue(alice,1)).to.be.revertedWithCustomError(token,'EnforcedPause');
    expect(await investment.issuedPurchase(ethers.id('purchase'))).to.equal(false);
    await token.unpause(); await issue(alice,1);
    await registry.setKycExpiration(alice.address,1);
    await expect(issue(alice,1,'expired')).to.be.revertedWithCustomError(token,'RecipientNotVerified');
  });
  it('bloquea transfer, transferFrom y batchTransfer, pero conserva compra y cobro', async function () {
    const { token, alice, bob, issue } = await loadFixture(fixture);
    await token.setProjectStatus(1); await issue(alice,3);
    await expect(token.connect(alice).transfer(bob.address,1)).to.be.revertedWithCustomError(token,'TransfersDisabled');
    await token.connect(alice).approve(bob.address,1);
    await expect(token.connect(bob).transferFrom(alice.address,bob.address,1)).to.be.revertedWithCustomError(token,'TransfersDisabled');
    await expect(token.connect(alice).batchTransfer([bob.address],[1])).to.be.revertedWithCustomError(token,'TransfersDisabled');
    await token.setProjectStatus(2); await token.distributeMonthly(202611,30000000);
    await token.connect(alice).claimRevenue();
  });
  it('exige operación, período válido/único, agente, fondos y no permite la ruta de reparto directo', async function () {
    const { token, alice, outsider, issue } = await loadFixture(fixture);
    await token.setProjectStatus(1); await issue(alice,1);
    await expect(token.distributeMonthly(202611,100)).to.be.revertedWithCustomError(token,'ProjectNotOperating');
    await token.setProjectStatus(2);
    await expect(token.connect(outsider).distributeMonthly(202611,100)).to.be.revertedWithCustomError(token,'NotAgent');
    for (const period of [0,202600,202613,199912]) await expect(token.distributeMonthly(period,100)).to.be.revertedWithCustomError(token,'InvalidPeriod');
    await expect(token.distributeRevenue(100,'bypass')).to.be.revertedWithCustomError(token,'UseMonthlyDistribution');
    await expect(token.distributeMonthly(202611,0)).to.be.revertedWithCustomError(token,'ZeroAmount');
    expect(await token.distributedPeriod(202611)).to.equal(false);
    await expect(token.distributeMonthly(202611,2000000000n)).to.be.reverted;
    expect(await token.distributedPeriod(202611)).to.equal(false);
    await token.distributeMonthly(202611,100);
    await expect(token.distributeMonthly(202611,200)).to.be.revertedWithCustomError(token,'PeriodAlreadyDistributed');
  });
  it('reparte a dos titulares, no reasigna ingresos a compras posteriores y cobra una sola vez', async function () {
    const { token, payment, alice, bob, issue } = await loadFixture(fixture);
    await token.setProjectStatus(1); await issue(alice,1,'a'); await issue(bob,3,'b'); await token.setProjectStatus(2);
    await token.distributeMonthly(202611,40000000);
    expect(await token.withdrawableRevenueOf(alice.address)).to.equal(10000000);
    expect(await token.withdrawableRevenueOf(bob.address)).to.equal(30000000);
    await issue(alice,4,'late');
    expect(await token.withdrawableRevenueOf(alice.address)).to.equal(10000000);
    await token.distributeMonthly(202612,80000000);
    expect(await token.withdrawableRevenueOf(alice.address)).to.equal(60000000);
    await token.connect(alice).claimRevenue();
    expect(await payment.balanceOf(alice.address)).to.equal(60000000);
    await expect(token.connect(alice).claimRevenue()).to.be.revertedWithCustomError(token,'NothingToClaim');
  });
  it('cierra sin borrar derechos, no reabre y permite cobrar lo ya asignado', async function () {
    const { token, alice, issue } = await loadFixture(fixture);
    await token.setProjectStatus(1); await issue(alice,1); await token.setProjectStatus(2); await token.distributeMonthly(202611,100);
    await token.setProjectStatus(3);
    await expect(issue(alice,1,'closed')).to.be.revertedWithCustomError(token,'ProjectNotPurchasable');
    await expect(token.distributeMonthly(202612,100)).to.be.revertedWithCustomError(token,'ProjectNotOperating');
    await expect(token.setProjectStatus(1)).to.be.revertedWithCustomError(token,'InvalidProjectTransition');
    await token.connect(alice).claimRevenue();
  });
});
