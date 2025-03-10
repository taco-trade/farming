import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, upgrades } from "hardhat";
import { MockToken__factory } from "../../typechain-types";
import { getConfig } from "../utils/config";


const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const config = getConfig();
  const [deployer] = await ethers.getSigners();

  const tokenAddrs = [config.Tokens.MockToken0!, config.Tokens.MockToken1!]

  for (const tokenAddr of tokenAddrs) {
    const token = MockToken__factory.connect(tokenAddr, deployer);
    console.log(`${await token.name()} balance of deployer: ${await token.balanceOf(deployer.address)}`)

    await token.mint(deployer.address, ethers.parseEther("100000"))

    console.log(`${await token.name()} balance of deployer: ${await token.balanceOf(deployer.address)}`)
  }

};

export default func;
func.tags = ["ExecMockToken"];
