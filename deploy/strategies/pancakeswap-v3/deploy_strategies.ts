import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, upgrades } from "hardhat";
import { getConfig } from "../../utils/config";
import { PancakeswapV3StrategyAddBaseTokenOnly__factory, PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate, PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate__factory } from "../../../typechain-types";
import { Strats } from "./consts";


const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const config = getConfig()
    const [deployer] = await ethers.getSigners();

    const strategies = [Strats.baseTokenOnlyWithCal]

    if (strategies.includes(Strats.baseTokenOnly)) {
        console.log(">> Deploying PancakeswapV3StrategiesAddBaseTokenOnly...")
        const PancakeswapV3StrategiesAddBaseTokenOnly = (await ethers.getContractFactory("PancakeswapV3StrategyAddBaseTokenOnly", deployer)) as PancakeswapV3StrategyAddBaseTokenOnly__factory
        const strategy = await upgrades.deployProxy(PancakeswapV3StrategiesAddBaseTokenOnly, [
            config.PancakeSwapV3.PancakeV3Factory,
            config.PancakeSwapV3.SwapRouter,
            config.PancakeSwapV3.NonfungiblePositionManager,
        ])
    
        await strategy.waitForDeployment()
        console.log("> Proxy address:", await strategy.getAddress());
        console.log("> Implementation address:", await upgrades.erc1967.getImplementationAddress(await strategy.getAddress()));
    
        // 4. 验证逻辑合约（仅在非本地网络执行）
        if (process.env.VERIFY === 'true' && hre.network.name !== "hardhat") {
            console.log(">> Verifying implementation contract");
            await hre.run("verify:verify", {
                address: await upgrades.erc1967.getImplementationAddress(await strategy.getAddress()),
                constructorArguments: [] // 可升级合约构造函数必须为空
            });
    
            // 验证代理合约
            await hre.run("verify:verify", {
                address: await strategy.getAddress(),
                constructorArguments: [],
            });
        }
    }

    if (strategies.includes(Strats.baseTokenOnlyWithCal)) {
        console.log(">> Deploying PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate...")
        const PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate = (await ethers.getContractFactory("PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate", deployer)) as PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate__factory
        const strategy = await upgrades.deployProxy(PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate, [
            config.PancakeSwapV3.PancakeV3Factory,
            config.PancakeSwapV3.SwapRouter,
            config.PancakeSwapV3.NonfungiblePositionManager,
        ])
    
        await strategy.waitForDeployment()
        console.log("> Proxy address:", await strategy.getAddress());
        console.log("> Implementation address:", await upgrades.erc1967.getImplementationAddress(await strategy.getAddress()));
    
        // 4. 验证逻辑合约（仅在非本地网络执行）
        if (process.env.VERIFY === 'true' && hre.network.name !== "hardhat") {
            console.log(">> Verifying implementation contract");
            await hre.run("verify:verify", {
                address: await upgrades.erc1967.getImplementationAddress(await strategy.getAddress()),
                constructorArguments: [] // 可升级合约构造函数必须为空
            });
    
            // 验证代理合约
            await hre.run("verify:verify", {
                address: await strategy.getAddress(),
                constructorArguments: [],
            });
        }
    }
};

export default func;
func.tags = ["PancakeswapV3Strategies"];
