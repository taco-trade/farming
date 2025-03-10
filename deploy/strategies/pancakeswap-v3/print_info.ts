import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, network } from "hardhat";
import { getConfig } from "../../utils/config";
import { Manager__factory, PancakeSwapV3Mint__factory } from "../../../typechain-types";


const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const config = getConfig();
  const [deployer] = await ethers.getSigners();
  const strategyAddr = config.PancakeSwapV3.Strategies.AddBaseTokenOnly!

  const strategy = PancakeSwapV3Mint__factory.connect(strategyAddr, deployer)
  console.log(await strategy.getAddress())
  console.log(`factory: ${await strategy.factory()}`)
  console.log(`router: ${await strategy.router()}`)
  console.log(`positionManager: ${await strategy.positionManager()}`)
};

export default func;
func.tags = ["PrintInfo"];
