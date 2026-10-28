const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture, time } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyUint } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");

const USDC = (n) => ethers.parseUnits(String(n), 6);
const DAY = 24 * 60 * 60;
const MONTH = 30 * DAY;
const YEAR = 12 * MONTH;
const h = (s) => ethers.keccak256(ethers.toUtf8Bytes(s));

// Causales comunes (BilateralAgreement)
const CAUSE_EXPIRATION = 1;
const CAUSE_MUTUAL_AGREEMENT = 2;

async function baseTerms(partyA, partyB, stablecoin, overrides = {}) {
  return {
    partyA: partyA.address,
    partyB: partyB.address,
    paymentToken: await stablecoin.getAddress(),
    duration: 5 * YEAR,
    periodLength: MONTH,
    curePeriod: 15 * DAY,
    renewalTerm: 5 * YEAR,
    documentURI: "ipfs://contrato",
    documentHash: h("contrato"),
    ...overrides,
  };
}

async function signAndActivate(agreement, a, b) {
  const version = await agreement.termsVersion();
  await agreement.connect(a).sign(version);
  await agreement.connect(b).sign(version);
  await agreement.connect(a).activate();
}

async function deployFixture() {
  const [franchisor, trust, operator, auditor, outsider] = await ethers.getSigners();
  const stablecoin = await ethers.deployContract("MockStablecoin");

  const franchise = await ethers.deployContract("FranchiseAgreement", [
    await baseTerms(franchisor, trust, stablecoin),
    {
      brand: {
        name: "Cafe Central",
        trademarkRegistration: "INPI 1234567",
        brandManualURI: "ipfs://marca",
        brandManualHash: h("marca"),
      },
      territory: { description: "Polanco, CDMX", exclusive: true, zones: [h("11550"), h("11560")] },
      royalty: {
        entryFee: USDC(20_000),
        royaltyBps: 500, // 5%
        advertisingFeeBps: 200, // 2%
        minimumRoyalty: USDC(1_000),
        paymentGracePeriod: 10 * DAY,
      },
      knowHow: { uri: "ipfs://manual-operativo", hash: h("manual v1"), version: 0, updatedAt: 0 },
      standards: { uri: "ipfs://estandares", hash: h("estandares v1"), version: 0, updatedAt: 0 },
      minimumInspectionScore: 70,
    },
  ]);

  const operating = await ethers.deployContract("OperatingAgreement", [
    await baseTerms(trust, operator, stablecoin, { duration: 2 * YEAR, renewalTerm: YEAR }),
    {
      store: { name: "Cafe Central Polanco", location: "Av. Masaryk 100, CDMX" },
      fees: { fixedFee: USDC(2_000), successFeeBps: 1_000, reviewPeriod: 7 * DAY, paymentGracePeriod: 5 * DAY },
      kpis: { minGrossSales: USDC(30_000), maxCostRatioBps: 8_500, maxConsecutiveMisses: 3 },
      controls: { reportDeadline: 10 * DAY, purchaseApprovalThreshold: USDC(5_000) },
      franchiseAgreement: await franchise.getAddress(),
    },
  ]);

  await stablecoin.mint(trust.address, USDC(1_000_000));
  await stablecoin.connect(trust).approve(await franchise.getAddress(), ethers.MaxUint256);
  await stablecoin.connect(trust).approve(await operating.getAddress(), ethers.MaxUint256);

  return { franchise, operating, stablecoin, franchisor, trust, operator, auditor, outsider };
}

async function activeFixture() {
  const ctx = await deployFixture();
  await signAndActivate(ctx.franchise, ctx.franchisor, ctx.trust);
  await signAndActivate(ctx.operating, ctx.trust, ctx.operator);
  return ctx;
}

const goodReport = {
  grossSales: USDC(50_000),
  costOfGoods: USDC(15_000),
  payroll: USDC(12_000),
  otherExpenses: USDC(8_000),
  headcount: 9,
  transactions: 6_200,
  reportHash: h("reporte"),
};

const badReport = { ...goodReport, grossSales: USDC(20_000), reportHash: h("reporte malo") };

describe("Contratos del fideicomiso", function () {
  describe("BilateralAgreement (común)", function () {
    it("sólo se activa con ambas firmas sobre la versión vigente", async function () {
      const { franchise, franchisor, trust, outsider } = await loadFixture(deployFixture);
      await expect(franchise.connect(outsider).sign(1)).to.be.revertedWithCustomError(franchise, "NotParty");

      await franchise.connect(franchisor).sign(1);
      await expect(franchise.connect(franchisor).activate()).to.be.revertedWithCustomError(franchise, "NotFullySigned");

      // Un cambio de términos invalida la firma anterior
      await franchise.connect(trust).addClause(1, 1, "Mantener el local abierto 12 h diarias");
      expect(await franchise.termsVersion()).to.equal(2);
      await expect(franchise.connect(trust).sign(1)).to.be.revertedWithCustomError(franchise, "TermsVersionMismatch");
      await franchise.connect(trust).sign(2);
      expect(await franchise.isFullySigned()).to.equal(false);
      await franchise.connect(franchisor).sign(2);
      await expect(franchise.connect(trust).activate()).to.emit(franchise, "Activated");

      expect(await franchise.isActive()).to.equal(true);
      expect(await franchise.clauseCount()).to.equal(1);
      await expect(franchise.connect(trust).addClause(1, 1, "x")).to.be.revertedWithCustomError(franchise, "InvalidStatus");
    });

    it("renovación requiere aprobación de ambas partes antes del vencimiento", async function () {
      const { franchise, franchisor, trust } = await loadFixture(activeFixture);
      const end = await franchise.endDate();
      await franchise.connect(franchisor).approveRenewal();
      expect(await franchise.endDate()).to.equal(end);
      await expect(franchise.connect(trust).approveRenewal()).to.emit(franchise, "Renewed");
      expect(await franchise.endDate()).to.equal(end + BigInt(5 * YEAR));
      expect(await franchise.renewals()).to.equal(1);
    });

    it("vencimiento y mutuo acuerdo", async function () {
      const { franchise, operating, trust, operator } = await loadFixture(activeFixture);

      await operating.connect(trust).proposeMutualTermination(true);
      expect(await operating.isActive()).to.equal(true);
      await expect(operating.connect(operator).proposeMutualTermination(true))
        .to.emit(operating, "Terminated")
        .withArgs(CAUSE_MUTUAL_AGREEMENT, operator.address, anyUint);

      await expect(franchise.expire()).to.be.revertedWithCustomError(franchise, "NotExpired");
      await time.increaseTo(await franchise.endDate());
      await franchise.expire();
      expect(await franchise.terminationCause()).to.equal(CAUSE_EXPIRATION);
      expect(await franchise.isBrandLicenseActive()).to.equal(false);
    });
  });

  describe("CONTRATO 1: FranchiseAgreement (franquiciante ↔ fideicomiso)", function () {
    it("cobra el canon de entrada al activarse", async function () {
      const { franchise, stablecoin, franchisor, trust } = await loadFixture(deployFixture);
      await signAndActivate(franchise, franchisor, trust);
      expect(await stablecoin.balanceOf(franchisor.address)).to.equal(USDC(20_000));
    });

    it("guarda marca, territorio y know-how versionado", async function () {
      const { franchise, franchisor, trust } = await loadFixture(activeFixture);
      expect((await franchise.brand()).name).to.equal("Cafe Central");
      expect((await franchise.territory()).exclusive).to.equal(true);
      expect(await franchise.isInTerritory(h("11550"))).to.equal(true);
      expect(await franchise.isInTerritory(h("01000"))).to.equal(false);
      expect(await franchise.isBrandLicenseActive()).to.equal(true);

      await expect(franchise.connect(trust).updateKnowHow("ipfs://v2", h("v2"))).to.be.revertedWithCustomError(
        franchise,
        "Unauthorized"
      );
      await franchise.connect(franchisor).updateKnowHow("ipfs://v2", h("v2"));
      expect((await franchise.knowHow()).version).to.equal(2);
      await expect(franchise.connect(trust).acknowledgeKnowHow(3)).to.be.revertedWithCustomError(franchise, "UnknownVersion");
      await franchise.connect(trust).acknowledgeKnowHow(2);
      expect(await franchise.knowHowAcknowledgedVersion()).to.equal(2);
    });

    it("calcula regalía con mínimo + fondo de publicidad y la paga al franquiciante", async function () {
      const { franchise, stablecoin, franchisor, trust } = await loadFixture(activeFixture);

      await expect(franchise.connect(trust).reportSales(0, USDC(50_000), h("v0"))).to.be.revertedWithCustomError(
        franchise,
        "PeriodNotClosed"
      );
      await time.increase(MONTH);

      // 5% de 50.000 = 2.500 + 2% = 1.000
      expect(await franchise.royaltyFor(USDC(50_000))).to.equal(USDC(3_500));
      // 5% de 10.000 = 500 < mínimo 1.000, + 2% = 200
      expect(await franchise.royaltyFor(USDC(10_000))).to.equal(USDC(1_200));

      await franchise.connect(trust).reportSales(0, USDC(50_000), h("v0"));
      const before = await stablecoin.balanceOf(franchisor.address);
      await expect(franchise.connect(trust).payRoyalty(0)).to.emit(franchise, "RoyaltyPaid").withArgs(0, trust.address, USDC(3_500));
      expect((await stablecoin.balanceOf(franchisor.address)) - before).to.equal(USDC(3_500));
      expect(await franchise.totalRoyaltiesPaid()).to.equal(USDC(3_500));
      await expect(franchise.connect(trust).payRoyalty(1)).to.be.revertedWithCustomError(franchise, "PeriodNotReported");
    });

    it("el fideicomiso puede delegar el reporte de ventas en la operadora", async function () {
      const { franchise, trust, operator } = await loadFixture(activeFixture);
      await time.increase(MONTH);
      await expect(franchise.connect(operator).reportSales(0, 1, h("x"))).to.be.revertedWithCustomError(franchise, "Unauthorized");
      await franchise.connect(trust).setSalesReporter(operator.address, true);
      await franchise.connect(operator).reportSales(0, USDC(40_000), h("x"));
      expect((await franchise.salesReport(0)).grossSales).to.equal(USDC(40_000));
    });

    it("regalías vencidas habilitan la terminación sólo si persisten tras el plazo de subsanación", async function () {
      const { franchise, franchisor, trust } = await loadFixture(activeFixture);
      const CAUSE = await franchise.CAUSE_ROYALTY_DEFAULT();

      await expect(franchise.connect(franchisor).notifyBreach(CAUSE, h("e"))).to.be.revertedWithCustomError(
        franchise,
        "CauseNotAllowed"
      );
      await time.increase(MONTH + 10 * DAY + 1);
      expect(await franchise.hasOverduePayments()).to.equal(true);

      // El fideicomiso no puede invocar causales del franquiciante
      await expect(franchise.connect(trust).notifyBreach(CAUSE, h("e"))).to.be.revertedWithCustomError(
        franchise,
        "CauseNotAllowed"
      );
      await franchise.connect(franchisor).notifyBreach(CAUSE, h("e"));
      await expect(franchise.connect(franchisor).terminateForCause(0)).to.be.revertedWithCustomError(
        franchise,
        "CurePeriodRunning"
      );

      // Subsana pagando: ya no se puede terminar por esta causal
      await franchise.connect(trust).reportSales(0, USDC(50_000), h("v0"));
      await franchise.connect(trust).payRoyalty(0);
      await time.increase(15 * DAY);
      await expect(franchise.connect(franchisor).terminateForCause(0)).to.be.revertedWithCustomError(franchise, "BreachCured");

      // Nuevo atraso sin subsanar -> terminación
      await time.increase(MONTH);
      await franchise.connect(franchisor).notifyBreach(CAUSE, h("e2"));
      await time.increase(15 * DAY);
      await expect(franchise.connect(franchisor).terminateForCause(1))
        .to.emit(franchise, "Terminated")
        .withArgs(CAUSE, franchisor.address, anyUint);
      expect(await franchise.isBrandLicenseActive()).to.equal(false);

      // Las regalías adeudadas se siguen pudiendo liquidar tras la terminación
      expect(await franchise.hasOverduePayments()).to.equal(true);
    });

    it("inspección reprobada habilita causal de estándares; una aprobada la subsana", async function () {
      const { franchise, franchisor } = await loadFixture(activeFixture);
      const CAUSE = await franchise.CAUSE_STANDARDS_BREACH();
      await franchise.connect(franchisor).recordInspection(55, h("inspeccion 1"));
      expect(await franchise.lastInspectionFailed()).to.equal(true);
      await franchise.connect(franchisor).notifyBreach(CAUSE, h("inspeccion 1"));
      await franchise.connect(franchisor).recordInspection(85, h("inspeccion 2"));
      await time.increase(15 * DAY);
      await expect(franchise.connect(franchisor).terminateForCause(0)).to.be.revertedWithCustomError(franchise, "BreachCured");
    });

    it("insolvencia: terminación inmediata", async function () {
      const { franchise, trust } = await loadFixture(activeFixture);
      await franchise.connect(trust).notifyBreach(await franchise.CAUSE_INSOLVENCY(), h("concurso"));
      await franchise.connect(trust).terminateForCause(0);
      expect(await franchise.status()).to.equal(2);
    });
  });

  describe("CONTRATO 2: OperatingAgreement (fideicomiso ↔ operadora)", function () {
    it("reporte, aprobación tácita y pago de honorarios fijo + éxito", async function () {
      const { operating, stablecoin, trust, operator } = await loadFixture(activeFixture);
      await time.increase(MONTH);
      // resultado = 50.000 - 35.000 = 15.000 -> 10% = 1.500 + fijo 2.000
      expect(await operating.feeFor(goodReport)).to.equal(USDC(3_500));

      await expect(operating.connect(trust).submitReport(0, goodReport)).to.be.revertedWithCustomError(operating, "Unauthorized");
      await operating.connect(operator).submitReport(0, goodReport);
      await expect(operating.payFees(0)).to.be.revertedWithCustomError(operating, "ReportNotAccepted");

      await time.increase(7 * DAY);
      expect(await operating.isReportAccepted(0)).to.equal(true);
      await operating.connect(trust).payFees(0);
      expect(await stablecoin.balanceOf(operator.address)).to.equal(USDC(3_500));
    });

    it("resultado negativo: sólo honorario fijo", async function () {
      const { operating } = await loadFixture(activeFixture);
      expect(await operating.feeFor({ ...goodReport, otherExpenses: USDC(40_000) })).to.equal(USDC(2_000));
    });

    it("el fideicomiso observa un reporte y la operadora lo corrige", async function () {
      const { operating, trust, operator } = await loadFixture(activeFixture);
      await time.increase(MONTH);
      await operating.connect(operator).submitReport(0, goodReport);
      await operating.connect(trust).disputeReport(0, h("faltan facturas"));
      await time.increase(30 * DAY);
      expect(await operating.isReportAccepted(0)).to.equal(false);
      expect(await operating.hasOverduePayments()).to.equal(false);

      await operating.connect(operator).resubmitReport(0, { ...goodReport, reportHash: h("corregido") });
      await operating.connect(trust).approveReport(0);
      expect(await operating.isReportAccepted(0)).to.equal(true);
      await expect(operating.connect(trust).disputeReport(0, h("x"))).to.be.revertedWithCustomError(
        operating,
        "InvalidReportStatus"
      );
    });

    it("honorarios impagos: la operadora puede terminar", async function () {
      const { operating, operator } = await loadFixture(activeFixture);
      await time.increase(MONTH);
      await operating.connect(operator).submitReport(0, goodReport);
      await time.increase(12 * DAY + 1);
      expect(await operating.hasOverduePayments()).to.equal(true);
      await operating.connect(operator).notifyBreach(await operating.CAUSE_FEE_DEFAULT(), h("e"));
      await time.increase(15 * DAY);
      await operating.connect(operator).terminateForCause(0);
      expect(await operating.status()).to.equal(2);
    });

    it("reporte atrasado habilita causal de incumplimiento de reporte", async function () {
      const { operating, trust } = await loadFixture(activeFixture);
      const CAUSE = await operating.CAUSE_REPORTING_DEFAULT();
      await time.increase(MONTH + 5 * DAY);
      await expect(operating.connect(trust).notifyBreach(CAUSE, h("e"))).to.be.revertedWithCustomError(
        operating,
        "CauseNotAllowed"
      );
      await time.increase(5 * DAY + 1);
      expect(await operating.isReportOverdue()).to.equal(true);
      await operating.connect(trust).notifyBreach(CAUSE, h("e"));
    });

    it("KPIs: tres períodos seguidos fuera de objetivo", async function () {
      const { operating, trust, operator } = await loadFixture(activeFixture);
      expect(await operating.meetsKpis(goodReport)).to.equal(true);
      expect(await operating.meetsKpis(badReport)).to.equal(false);

      const reports = [badReport, goodReport, badReport, badReport, badReport];
      for (let i = 0; i < reports.length; i++) {
        await time.increase(MONTH);
        await operating.connect(operator).submitReport(i, reports[i]);
        if (i === 3) expect(await operating.isKpiBreached()).to.equal(false);
      }
      expect(await operating.consecutiveKpiMisses()).to.equal(3);
      expect(await operating.isKpiBreached()).to.equal(true);
      await operating.connect(trust).notifyBreach(await operating.CAUSE_KPI_UNDERPERFORMANCE(), h("kpi"));
    });

    it("proveedores aprobados y compras sobre el umbral", async function () {
      const { operating, trust, operator } = await loadFixture(activeFixture);
      const cafe = h("proveedor-cafe");
      const leche = h("proveedor-leche");

      await operating.connect(trust).registerSupplier(cafe, "Cafes del Sur SA", "30-12345678-9");
      await operating.connect(operator).registerSupplier(leche, "Lacteos SRL", "30-87654321-0");
      expect((await operating.supplier(cafe)).approved).to.equal(true);
      expect((await operating.supplier(leche)).approved).to.equal(false);

      await expect(operating.connect(operator).recordPurchase(leche, USDC(100), h("f1"))).to.be.revertedWithCustomError(
        operating,
        "SupplierNotApproved"
      );
      await operating.connect(trust).setSupplierApproval(leche, true);

      await operating.connect(operator).recordPurchase(leche, USDC(1_000), h("f1"));
      await operating.connect(operator).recordPurchase(cafe, USDC(8_000), h("f2"));
      expect((await operating.purchase(0)).status).to.equal(1); // Approved
      expect((await operating.purchase(1)).status).to.equal(0); // Pending
      await operating.connect(trust).reviewPurchase(1, false);
      expect((await operating.purchase(1)).status).to.equal(2); // Rejected
      await expect(operating.connect(trust).reviewPurchase(1, true)).to.be.revertedWithCustomError(
        operating,
        "PurchaseNotPending"
      );
    });

    it("auditorías y seguro", async function () {
      const { operating, trust, operator, auditor, outsider } = await loadFixture(activeFixture);
      await expect(operating.connect(auditor).recordAudit(true, h("a"))).to.be.revertedWithCustomError(operating, "Unauthorized");
      await operating.connect(trust).setAuditor(auditor.address, true);
      await operating.connect(auditor).recordAudit(false, h("hallazgos"));
      expect(await operating.lastAuditFailed()).to.equal(true);
      await operating.connect(trust).notifyBreach(await operating.CAUSE_AUDIT_FAILURE(), h("hallazgos"));

      const expires = (await time.latest()) + YEAR;
      await operating.connect(operator).setInsurance("ipfs://poliza", h("poliza"), expires);
      expect(await operating.isInsuranceValid()).to.equal(true);
      await expect(operating.connect(outsider).setInsurance("x", h("x"), 0)).to.be.revertedWithCustomError(
        operating,
        "Unauthorized"
      );
    });

    it("si termina la franquicia (contrato 1) el fideicomiso termina la operación sin plazo", async function () {
      const { franchise, operating, franchisor, trust } = await loadFixture(activeFixture);
      const CAUSE = await operating.CAUSE_FRANCHISE_TERMINATED();
      await expect(operating.connect(trust).notifyBreach(CAUSE, h("x"))).to.be.revertedWithCustomError(
        operating,
        "CauseNotAllowed"
      );
      await franchise.connect(franchisor).notifyBreach(await franchise.CAUSE_INSOLVENCY(), h("x"));
      await franchise.connect(franchisor).terminateForCause(0);

      await operating.connect(trust).notifyBreach(CAUSE, h("x"));
      await operating.connect(trust).terminateForCause(0);
      expect(await operating.terminationCause()).to.equal(CAUSE);
    });
  });

  describe("Integración con FranchiseToken", function () {
    it("no reparte a inversores mientras haya regalías u honorarios vencidos", async function () {
      const { franchise, operating, stablecoin, trust, operator } = await loadFixture(activeFixture);
      const [owner] = await ethers.getSigners();
      const [, , , , , investor] = await ethers.getSigners();

      const registry = await ethers.deployContract("IdentityRegistry", [owner.address]);
      const compliance = await ethers.deployContract("FranchiseCompliance", [owner.address]);
      const token = await ethers.deployContract("FranchiseToken", [
        "Cafe Central Polanco",
        "CCPOL",
        0,
        10_000,
        await registry.getAddress(),
        await compliance.getAddress(),
        await stablecoin.getAddress(),
        ethers.ZeroAddress,
        owner.address,
      ]);
      await registry.addAgent(owner.address);
      await token.addAgent(trust.address);
      await registry.registerIdentity(investor.address, ethers.Wallet.createRandom().address, 32);
      await token.connect(trust).mint(investor.address, 100);
      await stablecoin.connect(trust).approve(await token.getAddress(), ethers.MaxUint256);

      await token.addSeniorObligation(await franchise.getAddress());
      await token.addSeniorObligation(await operating.getAddress());
      await expect(token.addSeniorObligation(await franchise.getAddress())).to.be.revertedWithCustomError(
        token,
        "ObligationAlreadyAdded"
      );

      await time.increase(MONTH + 12 * DAY + 1);
      await operating.connect(operator).submitReport(0, goodReport);
      await expect(token.connect(trust).distributeRevenue(USDC(10_000), "Mes 1"))
        .to.be.revertedWithCustomError(token, "SeniorPaymentsOverdue")
        .withArgs(await franchise.getAddress());

      await franchise.connect(trust).reportSales(0, goodReport.grossSales, h("v0"));
      await franchise.connect(trust).payRoyalty(0);
      await token.connect(trust).distributeRevenue(USDC(10_000), "Mes 1"); // honorarios aún no vencidos

      await time.increase(12 * DAY + 1);
      await expect(token.connect(trust).distributeRevenue(USDC(1), "x"))
        .to.be.revertedWithCustomError(token, "SeniorPaymentsOverdue")
        .withArgs(await operating.getAddress());
      await operating.connect(trust).payFees(0);

      await token.removeSeniorObligation(await operating.getAddress());
      expect(await token.seniorObligations()).to.deep.equal([await franchise.getAddress()]);
    });
  });
});
