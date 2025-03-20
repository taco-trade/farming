import hre from "hardhat";
import { Manager__factory } from "../typechain-types";
import { IERC20__factory } from "../typechain-types";
import { getDeployedAddressByModule } from "./utils/address";

const ManagerModule = "ManagerModule"
const StrategyModule = "StrategiesModule"
const TokenModule = "MockTokenModule"

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  const chainId = hre.network.config.chainId!;

  const managerAddr = getDeployedAddressByModule(ManagerModule, "Manager", chainId)
  const strategyAddr = getDeployedAddressByModule(StrategyModule, "PancakeSwapV3Mint", chainId)
  const token0Addr = getDeployedAddressByModule(TokenModule, "MockToken0", chainId)
  const token1Addr = getDeployedAddressByModule(TokenModule, "MockToken1", chainId)

  const manager = Manager__factory.connect(managerAddr, deployer);

  // Init user vault
  var userVault = await manager.userVaults(deployer.address);
  if (userVault == hre.ethers.ZeroAddress) {
    const tx = await manager.createUserVault();
    console.log("createUserVault:", tx.hash);
    await tx.wait();
  }
  userVault = await manager.userVaults(deployer.address);
  console.log("userVault:", userVault);

  const token0 = IERC20__factory.connect(token0Addr, deployer);
  const token1 = IERC20__factory.connect(token1Addr, deployer);
  const tx0 = await token0.approve(userVault, hre.ethers.parseEther("1000"));
  const tx1 = await token1.approve(userVault, hre.ethers.parseEther("1000"));
  console.log("approve:", tx0.hash, tx1.hash);
  await tx0.wait();
  await tx1.wait();

  // Add liquidity
  const mintParams = {
    token0: token0Addr,
    token1: token1Addr,
    fee: 3000,
    tickLower: -46020,
    tickUpper: 46020,
    amount0Desired: hre.ethers.parseEther("1000"),
    amount1Desired: hre.ethers.parseEther("1000"),
    amount0Min: 0,
    amount1Min: 0,
    recipient: deployer.address,
    deadline: 0,
  };
  // Encode strategy params
  const encodedParams = hre.ethers.AbiCoder.defaultAbiCoder().encode(
    [
      'bool',
      'tuple(address token0, address token1, uint24 fee, int24 tickLower, int24 tickUpper, uint256 amount0Desired, uint256 amount1Desired, uint256 amount0Min, uint256 amount1Min, address recipient, uint256 deadline)'
    ],
    [true, mintParams]
  );

  const workTx = await manager.work(userVault, 0, strategyAddr, encodedParams, { gasLimit: 1000000 , gasPrice: hre.ethers.parseUnits("1", "gwei")});
  console.log("work:", workTx.hash);
  await workTx.wait();
}

main().catch(console.error);