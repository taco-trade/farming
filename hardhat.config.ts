import { HardhatUserConfig, vars } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-ignition-ethers";
import "@nomicfoundation/hardhat-foundry";
import "@typechain/hardhat";

const BSC_TESTNET_RPC = vars.get("BSC_TESTNET_RPC");
const BASE_SEPOLIA_RPC = vars.get("BASE_SEPOLIA_RPC");
const SEPOLIA_RPC = vars.get("SEPOLIA_RPC");
const ETH_RPC = vars.get("ETH_RPC");
const PRIVATE_KEY = vars.get("PRIVATE_KEY");
const PROD_PRIVATE_KEY = vars.get("PROD_PRIVATE_KEY");
const BSC_SCAN_API_KEY = vars.get("BSC_SCAN_API_KEY");
const BASE_SCAN_API_KEY = vars.get("BASE_SCAN_API_KEY");
const ETH_SCAN_API_KEY = vars.get("ETH_SCAN_API_KEY");
const BASE_RPC = vars.get("BASE_RPC");

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  networks: {
    hardhat: {
      forking: {
        url: BSC_TESTNET_RPC,
        blockNumber: 48842800,
      },
    },
    base: {
      url: BASE_RPC,
      chainId: 8453,
      accounts: [PROD_PRIVATE_KEY],
    },
    ethereum: {
      url: ETH_RPC,
      chainId: 1,
      accounts: [PROD_PRIVATE_KEY],
    },
    bscTestnet: {
      url: BSC_TESTNET_RPC,
      chainId: 97,
      accounts: [PRIVATE_KEY],
    },
    baseSepolia: {
      url: BASE_SEPOLIA_RPC,
      chainId: 84532,
      accounts: [PRIVATE_KEY],
    },
    sepolia: {
      url: SEPOLIA_RPC,
      chainId: 11155111,
      accounts: [PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: {
      mainnet: ETH_SCAN_API_KEY,
      ethereum: ETH_SCAN_API_KEY,
      bscTestnet: BSC_SCAN_API_KEY,
      baseSepolia: BASE_SCAN_API_KEY,
      sepolia: ETH_SCAN_API_KEY,
      base: BASE_SCAN_API_KEY,
    },
    customChains: [
      {
        network: "baseSepolia",
        chainId: 84532,
        urls: {
          apiURL: "https://api-sepolia.basescan.org/api",
          browserURL: "https://sepolia.basescan.org", //
        },
      },
      {
        network: "base",
        chainId: 8453,
        urls: {
          apiURL: "https://api.basescan.org/api",
          browserURL: "https://basescan.org",
        }
      }
    ],
  }
};

export default config;
