import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, upgrades } from "hardhat";
import { getConfig } from "../../utils/config";
import { PancakeswapV3StrategyAddBaseTokenOnly__factory, PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate__factory } from "../../../typechain-types";
import { Strats } from "./consts";


const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const config = getConfig()
    const [deployer] = await ethers.getSigners();

    const strategies = [Strats.baseTokenOnlyWithCal]


    if (strategies.includes(Strats.baseTokenOnly)) {
        const proxyAddress = config.PancakeSwapV3.Strategies.AddBaseTokenOnly!
        console.log("Upgrading AddBaseTokenOnly proxy...");
        const PancakeswapV3StrategiesAddBaseTokenOnly = (await ethers.getContractFactory("PancakeswapV3StrategyAddBaseTokenOnly", deployer)) as PancakeswapV3StrategyAddBaseTokenOnly__factory
    
        const upgraded = await upgrades.upgradeProxy(proxyAddress, PancakeswapV3StrategiesAddBaseTokenOnly);
        await upgraded.waitForDeployment();
        const recipient = upgraded.deploymentTransaction();
        await recipient?.wait(20);
    
        console.log("Proxy upgraded");
    
        const newImplementationAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);
        console.log("New implementation address:", newImplementationAddress);
    
        console.log("Verifying new implementation...");
        try {
            await hre.run("verify:verify", {
                address: newImplementationAddress,
                constructorArguments: [],
            });
            console.log("Verification successful");
        } catch (error) {
            console.error("Verification failed:", error);
            console.log("You may need to verify manually");
        }
    }


    if (strategies.includes(Strats.baseTokenOnlyWithCal)) {
        const proxyAddress = config.PancakeSwapV3.Strategies.AddBaseTokenOnlyWithCalculate!
        console.log("Upgrading AddBaseTokenOnlyWithCalculate proxy...");
        const PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate = (await ethers.getContractFactory("PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate", deployer)) as PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate__factory
    
        const upgraded = await upgrades.upgradeProxy(proxyAddress, PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate);
        await upgraded.waitForDeployment();
        const recipient = upgraded.deploymentTransaction();
        await recipient?.wait(20);
    
        console.log("Proxy upgraded");
    
        const newImplementationAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);
        console.log("New implementation address:", newImplementationAddress);
    
        console.log("Verifying new implementation...");
        try {
            await hre.run("verify:verify", {
                address: newImplementationAddress,
                constructorArguments: [],
            });
            console.log("Verification successful");
        } catch (error) {
            console.error("Verification failed:", error);
            console.log("You may need to verify manually");
        }
    }
    

};

export default func;
func.tags = ["UpgradePancakeswapV3Strategies"];
