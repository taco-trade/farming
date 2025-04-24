import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { ethers } from "hardhat";

const MockTokenModule = buildModule("MockTokenModule", (m) => {
  const deployer = m.getAccount(0);
  const token0 = m.contract("MockToken",["MokeToken0", "MokeToken0", 18, deployer], { id: "MockToken0"});
  const token1 = m.contract("MockToken",["MokeToken1", "MokeToken1", 18, deployer], { id: "MockToken1"});

  m.call(token0, "mint", [deployer, ethers.parseEther("10000")])
  m.call(token1, "mint", [deployer, ethers.parseEther("10000")])
  return { token0, token1 };
});

export default MockTokenModule;
