require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
require("@nomicfoundation/hardhat-verify");
require("hardhat-deploy");

/** @type import('hardhat/config').HardhatUserConfig */

const TELOS_RPC_URL = process.env.TELOS_RPC_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY;

module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    Telos: {
      url: TELOS_RPC_URL,
      accounts: [PRIVATE_KEY],
      chainId: 41,
      allowUnlimitedContractSize: true,
      // blockConfirmations: 6,
    },
    hardhat: {
      chainId: 31337,
      allowUnlimitedContractSize: true,
    },
    localhost: {
      url: "http://127.0.0.1:8545/",
      chainId: 31337,
    },
  },

  solidity: {
    compilers: [{ version: "0.8.19" }, { version: "0.8.20" }],

    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },

  namedAccounts: {
    deployer: {
      default: 0,
      1: 0,
    },
  },
};
