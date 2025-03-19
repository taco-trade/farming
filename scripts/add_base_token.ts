import hre, { ethers } from "hardhat";
import { Manager__factory, PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate__factory } from "../typechain-types";
import { IERC20__factory } from "../typechain-types";
import { getDeployedAddressByModule } from "./utils/address";

// const StrategiesMODULE = "StrategiesWithProxyModule"  // pancakev3
const StrategiesMODULE = "StrategiesUniswapV3Module"  // uniswapv3
const ManagerMODULE = "ManagerProxyModule"
const TokenMODULE = "MockTokenModule"

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  const chainId = hre.network.config.chainId!;

  const managerAddr = getDeployedAddressByModule(ManagerMODULE, "TransparentUpgradeableProxy", chainId)
  // const StrategiesABTWCProxyAddr = getDeployedAddressByModule(StrategiesMODULE, "StrategiesABTWCProxy", chainId)  // pancakeV3
  const StrategiesABTWCProxyAddr = getDeployedAddressByModule(StrategiesMODULE, "StrategiesUniswapV3ABTProxy", chainId)  // uniswapV3
  const token0Addr = getDeployedAddressByModule(TokenMODULE, "MockToken0", chainId)
  const token1Addr = getDeployedAddressByModule(TokenMODULE, "MockToken1", chainId)


  const manager = Manager__factory.connect(managerAddr, deployer);

  const userVault = await manager.userVaults(deployer.address);
  if (userVault == ethers.ZeroAddress) {
    const tx = await manager.createUserVault();
    console.log("createUserVault:", tx.hash);
    await tx.wait();
  }
  console.log("userVault:", userVault);
  const strategy = PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate__factory.connect(StrategiesABTWCProxyAddr, deployer)
  await strategy.setVaultsOk([userVault], true)


  const token0 = IERC20__factory.connect(token0Addr, deployer);
  const token1 = IERC20__factory.connect(token1Addr, deployer);
  const tx0 = await token0.approve(userVault, hre.ethers.parseEther("100"));
  const tx1 = await token1.approve(userVault, hre.ethers.parseEther("100"));
  console.log("approve:", tx0.hash, tx1.hash);
  await tx0.wait();
  await tx1.wait();

  const params = {
    baseToken: token0Addr,
    farmingToken: token1Addr,
    totalAmount: ethers.parseEther("100"),
    fee: 3000,
    tickLower: -46020,  // todo: config
    tickUpper: 46020,  // todo: config
    amount0Min: ethers.parseEther("0"), 
    amount1Min: ethers.parseEther("0"),  
    swapPath: ethers.solidityPacked(
      ["address", "uint24", "address"],
      [token0Addr, 3000, token1Addr])
  }

  const encodedParams = ethers.AbiCoder.defaultAbiCoder().encode(
    [
      'tuple(address baseToken,address farmingToken,uint256 totalAmount,uint24 fee,int24 tickLower,int24 tickUpper,uint256 amount0Min,uint256 amount1Min,bytes swapPath)'
    ],
    [params]
  );

  const workTx = await manager.work(0, StrategiesABTWCProxyAddr, encodedParams, { gasLimit: 1000000, gasPrice: ethers.parseUnits("10", "gwei") });
  console.log("work:", workTx.hash);
  await workTx.wait();
}

main().catch(console.error);