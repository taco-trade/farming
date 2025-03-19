import { HardhatUserConfig, vars } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-ignition-ethers";
import "@nomicfoundation/hardhat-foundry";
import "@typechain/hardhat";

const BSC_TESTNET_RPC = vars.get("BSC_TESTNET_RPC");
const BASE_SEPOLIA_RPC = vars.get("BASE_SEPOLIA_RPC");
const SEPOLIA_RPC = vars.get("SEPOLIA_RPC");
const PRIVATE_KEY = vars.get("PRIVATE_KEY");
const BSC_SCAN_API_KEY = vars.get("BSC_SCAN_API_KEY");
const BASE_SCAN_API_KEY = vars.get("BASE_SCAN_API_KEY");
const ETH_SCAN_API_KEY = vars.get("ETH_SCAN_API_KEY");

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
      bscTestnet: BSC_SCAN_API_KEY,
      baseSepolia: BASE_SCAN_API_KEY,
      sepolia: ETH_SCAN_API_KEY,
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
    ],
  }
};

export default config;
