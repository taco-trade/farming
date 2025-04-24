import hre, { ethers } from "hardhat";
import { getDeployedAddressByModule } from "./utils/address";
import { Manager__factory, MockToken__factory } from "../typechain-types";
import { ZeroAddress } from "ethers";

const ManagerModule = "ManagerProxyModule"
const StrategyModule = "StrategiesUniswapV3Module"

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  const chainId = hre.network.config.chainId!;
  
  // Get addresses for Manager and ZapMint strategy contracts
  const managerAddr = getDeployedAddressByModule(ManagerModule, "Manager", chainId)
  const strategyAddr = getDeployedAddressByModule(StrategyModule, "StrategiesUniswapV3ZapMintProxy", chainId)
  const manager = Manager__factory.connect(managerAddr, deployer);

  // Step 1: Initialize user vault if it doesn't exist
  var userVault = await manager.userVaults(deployer.address);
  if (userVault == hre.ethers.ZeroAddress) {
    const tx = await manager.createUserVault(ZeroAddress);
    console.log("createUserVault:", tx.hash);
    await tx.wait();
  }
  userVault = await manager.userVaults(deployer.address);
  console.log("userVault:", userVault);

  // Token addresses for the Uniswap V3 position
  const t0Addr = "0x4200000000000000000000000000000000000006" // WETH
  const t1Addr = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913" // USDC

  // Step 2: Approve tokens for vault to spend
  const token0 = MockToken__factory.connect(t0Addr, deployer);
  const tx0 = await token0.approve(userVault, hre.ethers.parseEther("100000"));
  await tx0.wait();
  const token1 = MockToken__factory.connect(t1Addr, deployer);
  const tx1 = await token1.approve(userVault, hre.ethers.parseEther("100000"));
  await tx1.wait();

  // Step 3: Configure parameters for the ZapMint strategy
  // t0Addr < t1Addr
  const strategyParams = {
    token0: t0Addr,              // Token0 in the pool
    token1: t1Addr,              // Token1 in the pool
    amount0: ethers.parseEther("0.0005"), // token0 amount
    amount1: "2633838",          // token1 amount
    fee: 500,                    // pool fee tier
    tickLower: -203370,          // Lower price bound for position
    tickUpper: -200320,          // Upper price bound for position
    amount0Min: 0,               // Minimum amount of token0 (slippage protection)
    amount1Min: 0,               // Minimum amount of token1 (slippage protection)
    token0SwapPath: ethers.solidityPacked(
      ["address", "uint24", "address"],
      [t0Addr, 500, t1Addr]),    // Swap path for token0 to token1
    token1SwapPath: ethers.solidityPacked(
      ["address", "uint24", "address"],
      [t1Addr, 500, t0Addr]),    // Swap path for token1 to token0
    userFund: true               // true: use funds from user wallet, false: use funds from vault
  };
  
  // Encode strategy parameters for contract interaction
  const encodedParams = hre.ethers.AbiCoder.defaultAbiCoder().encode(
    [
      'tuple(address token0, address token1, uint256 amount0, uint256 amount1, uint24 fee, int24 tickLower, int24 tickUpper, uint256 amount0Min, uint256 amount1Min, bytes token0SwapPath, bytes token1SwapPath, bool userFund)'
    ],
    [strategyParams]
  );

  // Execute the strategy through the Manager contract
  const workTx = await manager.work(userVault, 0, strategyAddr, encodedParams);
  console.log("work:", workTx.hash);
  await workTx.wait();
  
  console.log("ZapMint operation completed successfully");
}

main().catch((error) => {
  console.error("Error executing script:", error);
  process.exit(1);
});