import hre from "hardhat";
import { Manager__factory } from "../typechain-types";
import { ZeroAddress } from "ethers";
import { getDeployedAddressByModule } from "./utils/address";

const ManagerModule = "ManagerProxyModule"
const StrategyModule = "StrategiesUniswapV3Module"

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  const chainId = hre.network.config.chainId!;
  const managerAddr = getDeployedAddressByModule(ManagerModule, "Manager", chainId)
  const strategyAddr = getDeployedAddressByModule(StrategyModule, "StrategiesUniswapV3DecProxy", chainId)
  const manager = Manager__factory.connect(managerAddr, deployer);

  const userVault = await manager.userVaults(deployer.address);
  if (userVault == hre.ethers.ZeroAddress) {
    const tx = await manager.createUserVault(ZeroAddress);
    console.log("createUserVault:", tx.hash);
    await tx.wait();
  }
  console.log("userVault:", userVault);

  const decreaseLiquidityParams = {
    liquidity: "337551732430",
    amount0Min: 0,
    amount1Min: 0,
    recipient: 0, // 0: user, 1: vault
  };

  const encodedParams = hre.ethers.AbiCoder.defaultAbiCoder().encode(
    [
      'tuple(uint128 liquidity, uint256 amount0Min, uint256 amount1Min, uint8 recipient)'
    ],
    [decreaseLiquidityParams]
  );

  const workTx = await manager.work(userVault, 2, strategyAddr, encodedParams);
  console.log("work:", workTx.hash);
  await workTx.wait();
}

main().catch(console.error);