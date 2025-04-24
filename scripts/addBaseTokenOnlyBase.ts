import hre, { ethers } from "hardhat";
import { getDeployedAddressByModule } from "./utils/address";
import { Manager__factory, MockToken__factory } from "../typechain-types";
import { ZeroAddress } from "ethers";

const ManagerModule = "ManagerProxyModule"
const StrategyModule = "StrategiesUniswapV3Module"

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  const chainId = hre.network.config.chainId!;
  const managerAddr = getDeployedAddressByModule(ManagerModule, "Manager", chainId)
  const strategyAddr = getDeployedAddressByModule(StrategyModule, "StrategiesUniswapV3ABTProxy", chainId)
  const manager = Manager__factory.connect(managerAddr, deployer);

  // Init user vault
  var userVault = await manager.userVaults(deployer.address);
  if (userVault == hre.ethers.ZeroAddress) {
    const tx = await manager.createUserVault(ZeroAddress);
    console.log("createUserVault:", tx.hash);
    await tx.wait();
  }
  userVault = await manager.userVaults(deployer.address);
  console.log("userVault:", userVault);

  // const t1Addr = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913" // USDC
  // const t0Addr = "0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2" // USDT

  const t0Addr = "0x4200000000000000000000000000000000000006" // WETH
  const t1Addr = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913" // USDC
  // Approve tokens
  const token0 = MockToken__factory.connect(t0Addr, deployer);
  // const tx0 = await token0.approve(userVault, hre.ethers.parseEther("100000"));
  // await tx0.wait();

  // Add liquidity
  const strategyParams = {
    baseToken: t0Addr,
    farmingToken: t1Addr,
    totalAmount: ethers.parseEther("0.0021"),
    fee: 500,
    tickLower: -201370,
    tickUpper: -200320,
    amount0Min: 0,
    amount1Min: 0,
    swapPath: ethers.solidityPacked(
      ["address", "uint24", "address"],
      [t0Addr, 500, t1Addr]),
  };
  // Encode strategy params
  const encodedParams = hre.ethers.AbiCoder.defaultAbiCoder().encode(
    [
      'bool',
      'tuple(address baseToken, address farmingToken, uint256 totalAmount, uint24 fee, int24 tickLower, int24 tickUpper, uint256 amount0Min, uint256 amount1Min, bytes swapPath)'
    ],
    [true, strategyParams]
  );

  const workTx = await manager.work(userVault, 0, strategyAddr, encodedParams, { gasLimit: 1000000});
  console.log("work:", workTx.hash);
  await workTx.wait();
}

main().catch(console.error);