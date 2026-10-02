const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture, time } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

const MEXICO = 484;
const USA = 840;
const NORTH_KOREA = 408;
const USDC = (n) => ethers.parseUnits(String(n), 6);

describe("FranchiseToken (ERC-3643)", function () {
  async function deployFixture() {
    const [owner, agent, alice, bob, carol, outsider, aliceNew] = await ethers.getSigners();

    const stablecoin = await ethers.deployContract("MockStablecoin");
    const registry = await ethers.deployContract("IdentityRegistry", [owner.address]);
    const compliance = await ethers.deployContract("FranchiseCompliance", [owner.address]);

    const token = await ethers.deployContract("FranchiseToken", [
      "Cafe Central Polanco",
      "CCPOL",
      0, // participaciones enteras
      10_000, // máximo de participaciones
      await registry.getAddress(),
      await compliance.getAddress(),
      await stablecoin.getAddress(),
      ethers.ZeroAddress,
      owner.address,
    ]);

    await registry.addAgent(agent.address);
    await registry.addAgent(await token.getAddress()); // para recoveryAddress
    await token.addAgent(agent.address);

    // Identidades (en producción: direcciones de contratos ONCHAINID)
    const idAlice = ethers.Wallet.createRandom().address;
    const idBob = ethers.Wallet.createRandom().address;
    const idCarol = ethers.Wallet.createRandom().address;
    await registry
      .connect(agent)
      .batchRegisterIdentity([alice.address, bob.address, carol.address], [idAlice, idBob, idCarol], [MEXICO, MEXICO, USA]);

    await stablecoin.mint(agent.address, USDC(1_000_000));
    await stablecoin.connect(agent).approve(await token.getAddress(), ethers.MaxUint256);

    return { token, registry, compliance, stablecoin, owner, agent, alice, bob, carol, outsider, aliceNew, idAlice };
  }

  describe("Despliegue", function () {
    it("configura metadatos, registry y compliance", async function () {
      const { token, registry, compliance } = await loadFixture(deployFixture);
      expect(await token.name()).to.equal("Cafe Central Polanco");
      expect(await token.symbol()).to.equal("CCPOL");
      expect(await token.decimals()).to.equal(0);
      expect(await token.maxSupply()).to.equal(10_000);
      expect(await token.identityRegistry()).to.equal(await registry.getAddress());
      expect(await token.compliance()).to.equal(await compliance.getAddress());
      expect(await compliance.getTokenBound()).to.equal(await token.getAddress());
    });

    it("guarda la información de la franquicia", async function () {
      const { token } = await loadFixture(deployFixture);
      const info = {
        franchiseName: "Cafe Central - Polanco",
        brand: "Cafe Central",
        location: "CDMX, Mexico",
        legalDocumentURI: "ipfs://bafy...",
        legalDocumentHash: ethers.keccak256(ethers.toUtf8Bytes("contrato")),
        valuation: USDC(500_000),
      };
      await expect(token.setFranchiseInfo(info)).to.emit(token, "FranchiseInfoUpdated");
      const stored = await token.franchiseInfo();
      expect(stored.brand).to.equal("Cafe Central");
      expect(stored.valuation).to.equal(USDC(500_000));
    });
  });

  describe("Emisión y transferencias", function () {
    it("sólo agentes emiten y sólo a inversores verificados", async function () {
      const { token, agent, alice, outsider } = await loadFixture(deployFixture);
      await expect(token.connect(alice).mint(alice.address, 10)).to.be.revertedWithCustomError(token, "NotAgent");
      await expect(token.connect(agent).mint(outsider.address, 10)).to.be.revertedWithCustomError(
        token,
        "RecipientNotVerified"
      );
      await token.connect(agent).mint(alice.address, 100);
      expect(await token.balanceOf(alice.address)).to.equal(100);
      expect(await token.holderCount()).to.equal(1);
    });

    it("respeta el máximo de participaciones", async function () {
      const { token, agent, alice } = await loadFixture(deployFixture);
      await expect(token.connect(agent).mint(alice.address, 10_001)).to.be.revertedWithCustomError(
        token,
        "MaxSupplyExceeded"
      );
    });

    it("permite transferir entre verificados y bloquea a no verificados", async function () {
      const { token, agent, alice, bob, outsider } = await loadFixture(deployFixture);
      await token.connect(agent).mint(alice.address, 100);
      await token.connect(alice).transfer(bob.address, 40);
      expect(await token.balanceOf(bob.address)).to.equal(40);
      await expect(token.connect(alice).transfer(outsider.address, 1)).to.be.revertedWithCustomError(
        token,
        "RecipientNotVerified"
      );
    });

    it("transferFrom aplica las mismas reglas y consume allowance", async function () {
      const { token, agent, alice, bob, carol } = await loadFixture(deployFixture);
      await token.connect(agent).mint(alice.address, 100);
      await token.connect(alice).approve(carol.address, 30);
      await token.connect(carol).transferFrom(alice.address, bob.address, 30);
      expect(await token.balanceOf(bob.address)).to.equal(30);
      expect(await token.allowance(alice.address, carol.address)).to.equal(0);
    });

    it("bloquea transferencias si el KYC expiró", async function () {
      const { token, registry, agent, alice, bob } = await loadFixture(deployFixture);
      await token.connect(agent).mint(alice.address, 100);
      const now = await time.latest();
      await registry.connect(agent).setKycExpiration(bob.address, now + 100);
      await time.increase(200);
      await expect(token.connect(alice).transfer(bob.address, 1)).to.be.revertedWithCustomError(
        token,
        "RecipientNotVerified"
      );
    });

    it("pausa bloquea transferencias de inversores", async function () {
      const { token, agent, alice, bob } = await loadFixture(deployFixture);
      await token.connect(agent).mint(alice.address, 100);
      await token.connect(agent).pause();
      await expect(token.connect(alice).transfer(bob.address, 1)).to.be.revertedWithCustomError(token, "EnforcedPause");
      await token.connect(agent).unpause();
      await token.connect(alice).transfer(bob.address, 1);
    });

    it("batchMint y batchTransfer", async function () {
      const { token, agent, alice, bob, carol } = await loadFixture(deployFixture);
      await token.connect(agent).batchMint([alice.address, bob.address], [50, 60]);
      await token.connect(alice).batchTransfer([bob.address, carol.address], [10, 20]);
      expect(await token.balanceOf(alice.address)).to.equal(20);
      expect(await token.balanceOf(bob.address)).to.equal(70);
      expect(await token.balanceOf(carol.address)).to.equal(20);
      expect(await token.holderCount()).to.equal(3);
    });
  });

  describe("Compliance", function () {
    it("lock-up: permite emitir pero no transferir", async function () {
      const { token, compliance, agent, alice, bob } = await loadFixture(deployFixture);
      await compliance.setLockupEnd((await time.latest()) + 3600);
      await token.connect(agent).mint(alice.address, 100);
      await expect(token.connect(alice).transfer(bob.address, 1)).to.be.revertedWithCustomError(
        token,
        "ComplianceCheckFailed"
      );
      await time.increase(3601);
      await token.connect(alice).transfer(bob.address, 1);
    });

    it("tenencia máxima por inversor", async function () {
      const { token, compliance, agent, alice } = await loadFixture(deployFixture);
      await compliance.setMaxBalancePerInvestor(1_000);
      await token.connect(agent).mint(alice.address, 1_000);
      await expect(token.connect(agent).mint(alice.address, 1)).to.be.revertedWithCustomError(
        token,
        "ComplianceCheckFailed"
      );
    });

    it("países bloqueados", async function () {
      const { token, registry, compliance, agent, alice, bob } = await loadFixture(deployFixture);
      await compliance.setCountryBlocked(NORTH_KOREA, true);
      await token.connect(agent).mint(alice.address, 100);
      await registry.connect(agent).updateCountry(bob.address, NORTH_KOREA);
      await expect(token.connect(alice).transfer(bob.address, 1)).to.be.revertedWithCustomError(
        token,
        "ComplianceCheckFailed"
      );
    });

    it("máximo de inversores (permite reemplazar a un holder que sale)", async function () {
      const { token, compliance, agent, alice, bob, carol } = await loadFixture(deployFixture);
      await compliance.setMaxHolders(2);
      await token.connect(agent).batchMint([alice.address, bob.address], [100, 100]);
      await expect(token.connect(agent).mint(carol.address, 1)).to.be.revertedWithCustomError(
        token,
        "ComplianceCheckFailed"
      );
      await expect(token.connect(alice).transfer(carol.address, 50)).to.be.revertedWithCustomError(
        token,
        "ComplianceCheckFailed"
      );
      // Alice vende todo: el número de holders no crece
      await token.connect(alice).transfer(carol.address, 100);
      expect(await token.holderCount()).to.equal(2);
    });

    it("sólo el token vinculado llama a los hooks", async function () {
      const { compliance, alice, bob } = await loadFixture(deployFixture);
      await expect(compliance.connect(alice).transferred(alice.address, bob.address, 1)).to.be.revertedWithCustomError(
        compliance,
        "OnlyBoundToken"
      );
    });
  });

  describe("Congelamiento, transferencia forzada y quema", function () {
    it("congelar wallet bloquea envío y recepción", async function () {
      const { token, agent, alice, bob } = await loadFixture(deployFixture);
      await token.connect(agent).mint(alice.address, 100);
      await expect(token.connect(agent).setAddressFrozen(alice.address, true))
        .to.emit(token, "AddressFrozen")
        .withArgs(alice.address, true, agent.address);
      await expect(token.connect(alice).transfer(bob.address, 1)).to.be.revertedWithCustomError(token, "AddressIsFrozen");
      await expect(token.connect(bob).transfer(alice.address, 0)).to.be.revertedWithCustomError(token, "AddressIsFrozen");
    });

    it("congelamiento parcial limita el saldo libre", async function () {
      const { token, agent, alice, bob } = await loadFixture(deployFixture);
      await token.connect(agent).mint(alice.address, 100);
      await token.connect(agent).freezePartialTokens(alice.address, 70);
      await expect(token.connect(alice).transfer(bob.address, 31)).to.be.revertedWithCustomError(
        token,
        "InsufficientFreeBalance"
      );
      await token.connect(alice).transfer(bob.address, 30);
      await token.connect(agent).unfreezePartialTokens(alice.address, 70);
      await token.connect(alice).transfer(bob.address, 70);
    });

    it("forcedTransfer descongela lo necesario", async function () {
      const { token, agent, alice, bob } = await loadFixture(deployFixture);
      await token.connect(agent).mint(alice.address, 100);
      await token.connect(agent).freezePartialTokens(alice.address, 80);
      await token.connect(agent).forcedTransfer(alice.address, bob.address, 50);
      expect(await token.balanceOf(bob.address)).to.equal(50);
      expect(await token.getFrozenTokens(alice.address)).to.equal(50);
    });

    it("burn reduce supply y holders", async function () {
      const { token, agent, alice } = await loadFixture(deployFixture);
      await token.connect(agent).mint(alice.address, 100);
      await token.connect(agent).freezePartialTokens(alice.address, 100);
      await token.connect(agent).burn(alice.address, 100);
      expect(await token.totalSupply()).to.equal(0);
      expect(await token.getFrozenTokens(alice.address)).to.equal(0);
      expect(await token.holderCount()).to.equal(0);
    });
  });

  describe("Recuperación de wallet", function () {
    it("mueve saldo, congelados e ingresos pendientes a la nueva wallet", async function () {
      const { token, registry, agent, alice, bob, aliceNew, idAlice, stablecoin } = await loadFixture(deployFixture);
      await token.connect(agent).batchMint([alice.address, bob.address], [60, 40]);
      await token.connect(agent).freezePartialTokens(alice.address, 10);
      await token.connect(agent).distributeRevenue(USDC(1_000), "Q1");

      await expect(token.connect(agent).recoveryAddress(alice.address, aliceNew.address, idAlice))
        .to.emit(token, "RecoverySuccess")
        .withArgs(alice.address, aliceNew.address, idAlice);

      expect(await token.balanceOf(aliceNew.address)).to.equal(60);
      expect(await token.getFrozenTokens(aliceNew.address)).to.equal(10);
      expect(await registry.identity(aliceNew.address)).to.equal(idAlice);
      expect(await registry.investorCountry(aliceNew.address)).to.equal(MEXICO);
      expect(await registry.contains(alice.address)).to.equal(false);
      expect(await token.withdrawableRevenueOf(alice.address)).to.equal(0);

      await token.connect(aliceNew).claimRevenue();
      expect(await stablecoin.balanceOf(aliceNew.address)).to.equal(USDC(600));
    });

    it("rechaza una identidad que no coincide", async function () {
      const { token, agent, alice, aliceNew } = await loadFixture(deployFixture);
      await token.connect(agent).mint(alice.address, 10);
      await expect(
        token.connect(agent).recoveryAddress(alice.address, aliceNew.address, ethers.Wallet.createRandom().address)
      ).to.be.revertedWithCustomError(token, "IdentityMismatch");
    });
  });

  describe("Reparto de ingresos de la franquicia", function () {
    it("reparte a prorrata y respeta transferencias posteriores", async function () {
      const { token, stablecoin, agent, alice, bob, carol } = await loadFixture(deployFixture);
      await token.connect(agent).batchMint([alice.address, bob.address], [750, 250]);

      await token.connect(agent).distributeRevenue(USDC(10_000), "Regalias enero");
      expect(await token.withdrawableRevenueOf(alice.address)).to.equal(USDC(7_500));
      expect(await token.withdrawableRevenueOf(bob.address)).to.equal(USDC(2_500));

      // Alice vende 500 a Carol: lo ya devengado se queda con Alice
      await token.connect(alice).transfer(carol.address, 500);
      expect(await token.withdrawableRevenueOf(alice.address)).to.equal(USDC(7_500));
      expect(await token.withdrawableRevenueOf(carol.address)).to.equal(0);

      await token.connect(agent).distributeRevenue(USDC(1_000), "Regalias febrero");
      expect(await token.withdrawableRevenueOf(alice.address)).to.equal(USDC(7_750));
      expect(await token.withdrawableRevenueOf(bob.address)).to.equal(USDC(2_750));
      expect(await token.withdrawableRevenueOf(carol.address)).to.equal(USDC(500));

      await expect(token.connect(alice).claimRevenue())
        .to.emit(token, "RevenueClaimed")
        .withArgs(alice.address, USDC(7_750));
      expect(await stablecoin.balanceOf(alice.address)).to.equal(USDC(7_750));
      await expect(token.connect(alice).claimRevenue()).to.be.revertedWithCustomError(token, "NothingToClaim");
      expect(await token.totalRevenueDistributed()).to.equal(USDC(11_000));
    });

    it("wallets congeladas no pueden reclamar", async function () {
      const { token, agent, alice } = await loadFixture(deployFixture);
      await token.connect(agent).mint(alice.address, 100);
      await token.connect(agent).distributeRevenue(USDC(100), "Q1");
      await token.connect(agent).setAddressFrozen(alice.address, true);
      await expect(token.connect(alice).claimRevenue()).to.be.revertedWithCustomError(token, "AddressIsFrozen");
    });

    it("no se puede repartir sin tokens emitidos", async function () {
      const { token, agent } = await loadFixture(deployFixture);
      await expect(token.connect(agent).distributeRevenue(USDC(100), "Q1")).to.be.revertedWithCustomError(
        token,
        "NoHolders"
      );
    });
  });

  describe("Administración", function () {
    it("sólo el owner cambia nombre, símbolo y compliance", async function () {
      const { token, owner, alice } = await loadFixture(deployFixture);
      await expect(token.connect(alice).setName("X")).to.be.revertedWithCustomError(token, "OwnableUnauthorizedAccount");
      await token.connect(owner).setName("Nuevo Nombre");
      await token.connect(owner).setSymbol("NEW");
      expect(await token.name()).to.equal("Nuevo Nombre");
      expect(await token.symbol()).to.equal("NEW");

      const newCompliance = await ethers.deployContract("FranchiseCompliance", [owner.address]);
      await token.setCompliance(await newCompliance.getAddress());
      expect(await newCompliance.getTokenBound()).to.equal(await token.getAddress());
    });
  });
});
