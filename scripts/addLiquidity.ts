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
  const strategyAddr = getDeployedAddressByModule(StrategyModule, "StrategiesUniswapV3AddLiquidityProxy", chainId)
  console.log("managerAddr:", managerAddr);
  console.log("strategyAddr:", strategyAddr);
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

  const t0Addr = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48" // USDC
  const t1Addr = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2" // WETH

  //  const token0 = MockToken__factory.connect(t0Addr, deployer);
  //  const token1 = MockToken__factory.connect(t1Addr, deployer);  
  //  const tx0 = await token0.approve(userVault, ethers.parseEther("0.001"));
  //  console.log("approve token0:", tx0.hash);
  //  await tx0.wait();

  // Add liquidity
  const strategyParams = {
    amount0Desired: 2000000,
    amount1Desired: 0,
    amount0Min: ethers.parseEther("0"),
    amount1Min: ethers.parseEther("0"),
    userFund: true,
    token0SwapPath: ethers.solidityPacked(
      ["address", "uint24", "address"],
      [t0Addr, 500, t1Addr]),
    token1SwapPath: ethers.solidityPacked(
      ["address", "uint24", "address"],
      [t1Addr, 500, t0Addr]),
  };
  // Encode strategy params
  const encodedParams = hre.ethers.AbiCoder.defaultAbiCoder().encode(
    [
      'tuple(uint256 amount0Desired, uint256 amount1Desired, uint256 amount0Min, uint256 amount1Min, bool userFund, bytes token0SwapPath, bytes token1SwapPath)'
    ],
    [strategyParams]
  );

  const workTx = await manager.work(userVault, 1, strategyAddr, encodedParams, { gasLimit: 1000000});
  console.log("work:", workTx.hash);
  await workTx.wait();
}

main().catch(console.error);