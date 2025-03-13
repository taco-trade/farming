import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, network } from "hardhat";
import { getConfig } from "../../utils/config";
import { PancakeSwapV3Mint__factory } from "../../../typechain-types";


const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const config = getConfig()
    const [deployer] = await ethers.getSigners();

    console.log(">> Deploying PancakeSwapV3Mint...")
    const PancakeSwapV3Mint = (await ethers.getContractFactory("PancakeSwapV3Mint", deployer)) as PancakeSwapV3Mint__factory

    const pancakeSwapV3Mint = await PancakeSwapV3Mint.deploy(
        config.PancakeSwapV3.PancakeV3Factory!,
        config.PancakeSwapV3.SwapRouter!,
        config.PancakeSwapV3.NonfungiblePositionManager!,
    );

    const mintDeployTxReceipt = await pancakeSwapV3Mint.deploymentTransaction();
    console.log("mintDeployTxReceipt: ", await mintDeployTxReceipt?.blockHash)
    console.log("> PancakeSwapV3Mint deployed at", await pancakeSwapV3Mint.getAddress());
    // 等待 5 个区块确认
    console.log(`> Waiting for ${mintDeployTxReceipt?.confirmations} confirmations...`);
    await mintDeployTxReceipt?.wait(5);

    // 验证合约（仅在非本地网络执行）
    if (network.name !== "hardhat") {
        console.log(">> Verifying PancakeSwapV3Mint");
        await hre.run("verify:verify", {
            address: "0x824E38C39cA50eA03Bf4451c9b7564ba4a8F6fA4",
            constructorArguments: [
                config.PancakeSwapV3.PancakeV3Factory!,
                config.PancakeSwapV3.SwapRouter!,
                config.PancakeSwapV3.NonfungiblePositionManager!,
            ],
        });
    }


};

export default func;
func.tags = ["PancakeSwapV3Mint"];
