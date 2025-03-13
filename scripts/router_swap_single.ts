import hre, { ethers } from "hardhat";
import { ISwapRouter__factory, Manager__factory } from "../typechain-types";
import { IERC20__factory } from "../typechain-types";
import { getConfig } from "../deploy/utils/config";


async function main() {
  const config = getConfig();

  const [deployer] = await hre.ethers.getSigners();

  const routerAddr = config.PancakeSwapV3.SwapRouter!
  const router = ISwapRouter__factory.connect(routerAddr, deployer);


  const token0Addr = config.Tokens.MockToken0!
  const token1Addr = config.Tokens.MockToken1!

  const token0 = IERC20__factory.connect(token0Addr, deployer);
  const token1 = IERC20__factory.connect(token1Addr, deployer);
  const tx0 = await token0.approve(router, hre.ethers.parseEther("100000"));
  const tx1 = await token1.approve(router, hre.ethers.parseEther("100000"));
  console.log("approve:", tx0.hash, tx1.hash);
  await tx0.wait();
  await tx1.wait();

  const exactInputParams = {
    path: ethers.solidityPacked(
      ["address", "uint24", "address"],
      [token0Addr, 2500, token1Addr]),
    recipient: deployer.address,
    deadline: 1841675980,
    amountIn: ethers.parseEther("10"),
    amountOutMinimum: 0,
  }

  const tx = await router.exactInput(exactInputParams, { gasLimit: 1000000, gasPrice: ethers.parseUnits("10", "gwei") })
  console.log("exactInput:", tx.hash);
  await tx.wait();
}

main().catch(console.error);