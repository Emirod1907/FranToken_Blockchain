const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

const h = (value) => ethers.keccak256(ethers.toUtf8Bytes(value));

async function deployFixture() {
  const [trust, platform, verifier, investor, otherInvestor, outsider] = await ethers.getSigners();
  const stablecoin = await ethers.deployContract("MockStablecoin");
  const registry = await ethers.deployContract("IdentityRegistry", [trust.address]);
  const compliance = await ethers.deployContract("FranchiseCompliance", [trust.address]);
  const token = await ethers.deployContract("FranchiseToken", [
    "Test franchise",
    "TEST",
    0,
    100,
    await registry.getAddress(),
    await compliance.getAddress(),
    await stablecoin.getAddress(),
    ethers.ZeroAddress,
    trust.address,
  ]);
  const services = await ethers.deployContract("PlatformServicesAgreement", [
    trust.address,
    platform.address,
    ethers.encodeBytes32String("USD").slice(0, 8),
    2,
    50,
    h("servicios v1"),
  ]);
  const investment = await ethers.deployContract("InvestmentAgreement", [
    trust.address,
    await token.getAddress(),
    await services.getAddress(),
    verifier.address,
    1000,
    h("derechos v1"),
  ]);

  await token.connect(trust).addAgent(await investment.getAddress());
  await token.connect(trust).addAgent(trust.address);
  await token.connect(trust).setIssuanceController(await investment.getAddress());
  await registry.connect(trust).addAgent(trust.address);
  await registry.connect(trust).registerIdentity(investor.address, investor.address, 1);
  await registry.connect(trust).registerIdentity(otherInvestor.address, otherInvestor.address, 1);

  return { trust, platform, verifier, investor, otherInvestor, outsider, token, services, investment };
}

async function activeFixture() {
  const ctx = await deployFixture();
  await ctx.services.connect(ctx.trust).sign();
  await ctx.services.connect(ctx.platform).sign();
  await ctx.investment.connect(ctx.investor).acceptTerms();
  return ctx;
}

describe("Acuerdos de plataforma e inversión", function () {
  it("exige las dos firmas y calcula 0,5 % del precio sin incluir gas", async function () {
    const { trust, platform, outsider, services } = await loadFixture(deployFixture);
    expect(await services.isActive()).to.equal(false);
    await expect(services.connect(outsider).sign()).to.be.revertedWithCustomError(services, "NotParty");
    await services.connect(trust).sign();
    expect(await services.isActive()).to.equal(false);
    await expect(services.connect(platform).sign()).to.emit(services, "Activated");
    expect(await services.isActive()).to.equal(true);
    expect(await services.quote(1000)).to.deep.equal([5n, 995n]);
    expect(await services.quote(3000)).to.deep.equal([15n, 2985n]);
    expect(await services.quote(1)).to.deep.equal([0n, 1n]);
    await expect(services.connect(trust).sign()).to.be.revertedWithCustomError(services, "AlreadySigned");
  });

  it("rechaza una comisión que deje sin neto al fideicomiso", async function () {
    const { trust, platform } = await loadFixture(deployFixture);
    const factory = await ethers.getContractFactory("PlatformServicesAgreement");
    await expect(factory.deploy(trust.address, platform.address, "0x555344", 2, 10_000, h("terminos")))
      .to.be.revertedWithCustomError(factory, "InvalidTerms");
  });

  it("emite sólo después de conciliación atestada, aceptación y elegibilidad", async function () {
    const { trust, verifier, investor, otherInvestor, outsider, token, investment } = await loadFixture(activeFixture);
    const purchase = h("compra-1");
    const payment = h("pago-1");
    const evidence = h("comprobante-1");

    await expect(token.connect(trust).mint(investor.address, 1))
      .to.be.revertedWithCustomError(token, "UnauthorizedIssuer");

    await expect(investment.connect(outsider).issueAfterPayment(purchase, payment, investor.address, 1, 1000, evidence))
      .to.be.revertedWithCustomError(investment, "NotPaymentVerifier");
    await expect(investment.connect(verifier).issueAfterPayment(purchase, payment, investor.address, 1, 999, evidence))
      .to.be.revertedWithCustomError(investment, "AmountMismatch");
    await expect(investment.connect(verifier).issueAfterPayment(purchase, payment, otherInvestor.address, 1, 1000, evidence))
      .to.be.revertedWithCustomError(investment, "TermsNotAccepted");
    expect(await investment.issuedPurchase(purchase)).to.equal(false);

    await expect(investment.connect(verifier).issueAfterPayment(purchase, payment, investor.address, 1, 1000, evidence))
      .to.emit(investment, "PurchaseIssued")
      .withArgs(purchase, investor.address, payment, 1, 1000, 5, 995, evidence);
    expect(await token.balanceOf(investor.address)).to.equal(1);
    expect(await investment.totalUnitsIssued()).to.equal(1);

    await expect(investment.connect(verifier).issueAfterPayment(purchase, h("pago-2"), investor.address, 1, 1000, evidence))
      .to.be.revertedWithCustomError(investment, "PurchaseAlreadyIssued");
    await expect(investment.connect(verifier).issueAfterPayment(h("compra-2"), payment, investor.address, 1, 1000, evidence))
      .to.be.revertedWithCustomError(investment, "PaymentAlreadyUsed");
    expect(await token.balanceOf(investor.address)).to.equal(1);

    await investment.connect(trust).pause();
    await expect(investment.connect(verifier).issueAfterPayment(h("compra-3"), h("pago-3"), investor.address, 1, 1000, evidence))
      .to.be.revertedWithCustomError(investment, "EnforcedPause");
  });

  it("no registra la compra si el token rechaza la emisión", async function () {
    const { verifier, investor, token, investment } = await loadFixture(activeFixture);
    const purchase = h("compra-mayor-al-maximo");
    const payment = h("pago-mayor-al-maximo");
    await expect(investment.connect(verifier).issueAfterPayment(purchase, payment, investor.address, 101, 101000, h("comprobante")))
      .to.be.revertedWithCustomError(token, "MaxSupplyExceeded");
    expect(await investment.issuedPurchase(purchase)).to.equal(false);
    expect(await investment.usedPaymentReference(payment)).to.equal(false);
    expect(await investment.totalUnitsIssued()).to.equal(0);
  });

  it("no emite con servicios sin firmar ni con comprador no verificado", async function () {
    const { trust, platform, verifier, outsider, token, investment, services } = await loadFixture(deployFixture);
    const purchase = h("compra-sin-kyc");
    const payment = h("pago-sin-kyc");
    const evidence = h("comprobante-sin-kyc");
    await investment.connect(outsider).acceptTerms();
    await expect(investment.connect(verifier).issueAfterPayment(purchase, payment, outsider.address, 1, 1000, evidence))
      .to.be.revertedWithCustomError(investment, "ServicesNotActive");
    await services.connect(trust).sign();
    await services.connect(platform).sign();
    await expect(investment.connect(verifier).issueAfterPayment(purchase, payment, outsider.address, 1, 1000, evidence))
      .to.be.revertedWithCustomError(token, "RecipientNotVerified");
    expect(await investment.issuedPurchase(purchase)).to.equal(false);
  });

  it("rechaza otra instancia que no sea el controlador exclusivo del token", async function () {
    const { trust, verifier, investor, token, services } = await loadFixture(activeFixture);
    const otherAgreement = await ethers.deployContract("InvestmentAgreement", [
      trust.address,
      await token.getAddress(),
      await services.getAddress(),
      verifier.address,
      1000,
      h("otros derechos"),
    ]);
    await otherAgreement.connect(investor).acceptTerms();
    await expect(otherAgreement.connect(verifier).issueAfterPayment(
      h("compra-otra-instancia"), h("pago-otra-instancia"), investor.address, 1, 1000, h("comprobante")
    )).to.be.revertedWithCustomError(otherAgreement, "IssuanceControllerNotBound");
  });

  it("permite rotar el verificador sólo al fideicomiso", async function () {
    const { trust, verifier, outsider, investment } = await loadFixture(deployFixture);
    await expect(investment.connect(outsider).setPaymentVerifier(outsider.address))
      .to.be.revertedWithCustomError(investment, "OwnableUnauthorizedAccount");
    await expect(investment.connect(trust).setPaymentVerifier(outsider.address))
      .to.emit(investment, "PaymentVerifierChanged")
      .withArgs(verifier.address, outsider.address);
    expect(await investment.paymentVerifier()).to.equal(outsider.address);
  });
});
