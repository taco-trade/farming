import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, upgrades } from "hardhat";
import { MockToken__factory } from "../../typechain-types";


const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const [deployer] = await ethers.getSigners();

  const tokens = [
    {
      name: "MockToken1",
      symbol: "Token1",
      initialSupply: ethers.parseEther("1000000000")
    }
  ]

  for (const token of tokens) {
    console.log(`>> Deploying ${token.name}`)
    const MockToken = (await ethers.getContractFactory("MockToken", deployer)) as MockToken__factory
    const mockToken = await upgrades.deployProxy(MockToken, [
      token.name,
      token.symbol,
      token.initialSupply
    ]);

    await mockToken.waitForDeployment()
    const proxyAddr = await mockToken.getAddress()
    const implAddr = await upgrades.erc1967.getImplementationAddress(proxyAddr)

    console.log(`> ${token.name} Proxy address:", ${proxyAddr}`);
    console.log(`> ${token.name} Implementation address:", ${implAddr}`);

    if (process.env.VERIFY === 'true' && hre.network.name !== "hardhat") {
      console.log(">> Verifying implementation contract");
      await hre.run("verify:verify", {
        address: await upgrades.erc1967.getImplementationAddress(proxyAddr),
        constructorArguments: []
      });
      console.log(">> Verify implementation contract done!");
      console.log(">> Verifying proxy contract");
      // 验证代理合约
      await hre.run("verify:verify", {
        address: proxyAddr,
        constructorArguments: [],
      });
      console.log(">> Verify proxy contract done!");
    }
  }

};

export default func;
func.tags = ["MockToken"];
