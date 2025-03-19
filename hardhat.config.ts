import { HardhatUserConfig, vars } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-ignition-ethers";
import "@nomicfoundation/hardhat-foundry";
import "@typechain/hardhat";

const BSC_TESTNET_RPC = vars.get("BSC_TESTNET_RPC");
const PRIVATE_KEY = vars.get("PRIVATE_KEY");
const BSC_SCAN_API_KEY = vars.get("BSC_SCAN_API_KEY");
const BASE_TESTNET_RPC = vars.get("BASE_TESTNET_RPC");
const BASE_SCAN_API_KEY = vars.get("BASE_SCAN_API_KEY");

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  networks: {
    hardhat: {
      forking: {
        url: BSC_TESTNET_RPC,
        blockNumber: 48842800,
      },
    },
    bscTestnet: {
      url: BSC_TESTNET_RPC,
      chainId: 97,
      accounts: [PRIVATE_KEY],
    },
    baseTestnet: {
      url: BASE_TESTNET_RPC,
      chainId: 84532,
      accounts: [PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: {
      bscTestnet: BSC_SCAN_API_KEY,
      baseTestnet: BASE_SCAN_API_KEY,
    },
    customChains: [
      {
        network: "baseTestnet",
        chainId: 84532,
        urls: {
          apiURL: "https://api-sepolia.basescan.org/api",
          browserURL: "https://sepolia.basescan.org",
        },
      },
    ],
  }
};

export default config;
