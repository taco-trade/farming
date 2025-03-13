import hre from "hardhat";
import { Manager__factory } from "../typechain-types";
import { IERC20__factory } from "../typechain-types";
import { getDeployedAddressByModule } from "./utils/address";

const MODULE = "ManagerModule"

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  const chainId = hre.network.config.chainId!;
  const managerAddr = getDeployedAddressByModule(MODULE, "Manager", chainId)
  const strategyAddr = getDeployedAddressByModule(MODULE, "PancakeSwapV3Mint", chainId)
  const manager = Manager__factory.connect(managerAddr, deployer);

  var userVault = await manager.userVaults(deployer.address);
  if (userVault == hre.ethers.ZeroAddress) {
    const tx = await manager.createUserVault();
    console.log("createUserVault:", tx.hash);
    await tx.wait();
  }
  userVault = await manager.userVaults(deployer.address);
  console.log("userVault:", userVault);

  const token0 = IERC20__factory.connect("0x22D873Ce502a424c7909f1B950597b39F36b6608", deployer);
  const token1 = IERC20__factory.connect("0xaB1a4d4f1D656d2450692D237fdD6C7f9146e814", deployer);
  const tx0 = await token0.approve(userVault, hre.ethers.parseEther("100000"));
  const tx1 = await token1.approve(userVault, hre.ethers.parseEther("100000"));
  console.log("approve:", tx0.hash, tx1.hash);
  await tx0.wait();
  await tx1.wait();

  const mintParams = {
    token0: "0x22D873Ce502a424c7909f1B950597b39F36b6608",
    token1: "0xaB1a4d4f1D656d2450692D237fdD6C7f9146e814",
    fee: 2500,
    tickLower: -46050,
    tickUpper: 46050,
    amount0Desired: hre.ethers.parseEther("10000"),
    amount1Desired: hre.ethers.parseEther("10000"),
    amount0Min: 0,
    amount1Min: 0,
    recipient: deployer.address,
    deadline: 0,
  };
  const encodedParams = hre.ethers.AbiCoder.defaultAbiCoder().encode(
    [
      'tuple(address token0, address token1, uint24 fee, int24 tickLower, int24 tickUpper, uint256 amount0Desired, uint256 amount1Desired, uint256 amount0Min, uint256 amount1Min, address recipient, uint256 deadline)'
    ],
    [mintParams]
  );

  const workTx = await manager.work(0, strategyAddr, encodedParams, { gasLimit: 1000000 , gasPrice: hre.ethers.parseUnits("10", "gwei")});
  console.log("work:", workTx.hash);
  await workTx.wait();
}

main().catch(console.error);