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
  const strategyAddr = getDeployedAddressByModule(StrategyModule, "StrategiesUniswapV3CollectProxy", chainId)
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

  // Encode strategy params
  const encodedParams = hre.ethers.AbiCoder.defaultAbiCoder().encode(
    [
      'bool'
    ],
    [false]
  );

  const workTx = await manager.work(userVault, 7, strategyAddr, encodedParams);
  console.log("work:", workTx.hash);
  await workTx.wait();
}

main().catch(console.error);