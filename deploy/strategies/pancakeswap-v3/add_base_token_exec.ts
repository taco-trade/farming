import hre from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, network } from "hardhat";
import { getConfig } from "../../utils/config";
import { IERC20__factory, Manager__factory } from "../../../typechain-types";


const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const config = getConfig();
  const [deployer] = await ethers.getSigners();
  const strategyAddr = config.PancakeSwapV3.Strategies.AddBaseTokenOnly!
  const managerAddr = config.PancakeSwapV3.Manager!
  
  const manager = Manager__factory.connect(managerAddr, deployer);

  const userVault = await manager.userVaults(deployer.address);
  if (userVault == hre.ethers.ZeroAddress) {
    const tx = await manager.createUserVault();
    console.log("createUserVault:", tx.hash);
    await tx.wait();
  }
  console.log("userVault:", userVault);

  const token0 = IERC20__factory.connect(config.Tokens.MockToken0!, deployer);
  const token1 = IERC20__factory.connect(config.Tokens.MockToken1!, deployer);

  const tx0 = await token0.approve(userVault, ethers.parseEther("100000"));
  const tx1 = await token1.approve(userVault, ethers.parseEther("100000"));
  console.log("approve:", tx0.hash, tx1.hash);
  await tx0.wait();
  await tx1.wait();

  const params = {
    baseToken: config.Tokens.MockToken0!,
    farmingToken: config.Tokens.MockToken1!,
    totalAmount: ethers.parseEther("1000"),
    swapAmount: ethers.parseEther("50"),  // todo: calculate it 
    fee: 2500,
    tickLower: -46050,  // todo: config
    tickUpper: 46050,  // todo: config
    amount0Min: ethers.parseEther("900"), // todo: calculate it 
    amount1Min: ethers.parseEther("45"),  // todo: calculate it 
    swapPath: [config.Tokens.MockToken0!, config.Tokens.MockToken1!]
  }

  const encodedParams = hre.ethers.AbiCoder.defaultAbiCoder().encode(
    [
      'tuple(address baseToken,address farmingToken,uint256 totalAmount,uint256 swapAmount,uint24 fee,int24 tickLower,int24 tickUpper,uint256 amount0Min,uint256 amount1Min,bytes swapPath)'
    ],
    [params]
  );

  const workTx = await manager.work(0, strategyAddr, encodedParams, { gasLimit: 1000000 , gasPrice: ethers.parseUnits("10", "gwei")});
  console.log("work:", workTx.hash);
  await workTx.wait();
};


export default func;
func.tags = ["ExecPancakeswapV3StrategiesAddBaseTokenOnly"];