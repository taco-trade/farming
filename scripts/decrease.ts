import hre from "hardhat";
import { Manager__factory } from "../typechain-types";
import { getDeployedAddressByModule } from "./utils/address";

const MODULE = "ManagerModule"

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  const chainId = hre.network.config.chainId!;
  const managerAddr = getDeployedAddressByModule(MODULE, "Manager", chainId)
  const strategyAddr = getDeployedAddressByModule(MODULE, "PancakeSwapV3DecreaseLiquidity", chainId)
  const manager = Manager__factory.connect(managerAddr, deployer);

  const userVault = await manager.userVaults(deployer.address);
  if (userVault == hre.ethers.ZeroAddress) {
    const tx = await manager.createUserVault();
    console.log("createUserVault:", tx.hash);
    await tx.wait();
  }
  console.log("userVault:", userVault);

  const decreaseLiquidityParams = {
    liquidity: "1111135831458991694216",
    amount0Min: 0,
    amount1Min: 0,
    recipient: 1,
  };

  const encodedParams = hre.ethers.AbiCoder.defaultAbiCoder().encode(
    [
      'tuple(uint128 liquidity, uint256 amount0Min, uint256 amount1Min, uint8 recipient)'
    ],
    [decreaseLiquidityParams]
  );

  const workTx = await manager.work(2, strategyAddr, encodedParams, { gasLimit: 1000000, gasPrice: hre.ethers.parseUnits("10", "gwei") });
  console.log("work:", workTx.hash);
  await workTx.wait();
}

main().catch(console.error);