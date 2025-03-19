import hre from "hardhat";
import { Manager__factory } from "../typechain-types";
import { IERC20__factory } from "../typechain-types";
import { MockToken__factory } from "../typechain-types";
import { getDeployedAddressByModule } from "./utils/address";

const ManagerModule = "ManagerModule"
const StrategyModule = "StrategiesModule"
const TokenModule = "MockTokenModule"

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  const chainId = hre.network.config.chainId!;
  const managerAddr = getDeployedAddressByModule(ManagerModule, "Manager", chainId)
  const strategyAddr = getDeployedAddressByModule(StrategyModule, "PancakeSwapV3Mint", chainId)
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

  const t1Addr = getDeployedAddressByModule(TokenModule, "TA", chainId)
  const t0Addr = getDeployedAddressByModule(TokenModule, "TB", chainId)

  // Mint and Approve tokens
  const token0 = MockToken__factory.connect(t0Addr, deployer);
  const token1 = MockToken__factory.connect(t1Addr, deployer);
  const mint0 = await token0.mint(deployer.address, hre.ethers.parseEther("100000"));
  const mint1 = await token1.mint(deployer.address, hre.ethers.parseEther("100000"));
  await mint0.wait();
  await mint1.wait();
  console.log("mint:", mint0.hash, mint1.hash);

  const tx0 = await token0.approve(userVault, hre.ethers.parseEther("100000"));
  const tx1 = await token1.approve(userVault, hre.ethers.parseEther("100000"));
  console.log("approve:", tx0.hash, tx1.hash);
  await tx0.wait();
  await tx1.wait();

  // Add liquidity
  const mintParams = {
    token0: t0Addr,
    token1: t1Addr,
    fee: 3000,
    tickLower: -46080,
    tickUpper: 46080,
    amount0Desired: hre.ethers.parseEther("10000"),
    amount1Desired: hre.ethers.parseEther("10000"),
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