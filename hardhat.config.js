require("@nomicfoundation/hardhat-toolbox");

const { PRIVATE_KEY, SEPOLIA_RPC_URL, ETHERSCAN_API_KEY } = process.env;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: { enabled: true, runs: 200 },
    },
  },
  networks: {
    hardhat: {},
    localhost: { url: "http://127.0.0.1:8545" },
    // Red Besu QBFT local (infra/besu). Mnemonic público de prueba de Hardhat: sólo para esta red.
    besu: {
      url: process.env.BESU_RPC_URL || "http://127.0.0.1:18545",
      chainId: 2026,
      accounts: { mnemonic: "test test test test test test test test test test test junk", count: 6 },
    },
    ...(SEPOLIA_RPC_URL && PRIVATE_KEY
      ? { sepolia: { url: SEPOLIA_RPC_URL, accounts: [PRIVATE_KEY] } }
      : {}),
  },
  etherscan: { apiKey: ETHERSCAN_API_KEY || "" },
};
