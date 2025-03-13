import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, network } from "hardhat";
import { getConfig } from "../../utils/config";
import { Manager__factory } from "../../../typechain-types";


const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const config = getConfig()
    const [deployer] = await ethers.getSigners();

    console.log(">> Deploying Manager")
    const Manager = (await ethers.getContractFactory("Manager", deployer)) as Manager__factory

    const manager = await Manager.deploy(deployer.address, config.PancakeSwapV3.NonfungiblePositionManager);

    const managerDeployTxReceipt = await manager.deploymentTransaction();
    console.log("managerDeployTxReceipt: ", await managerDeployTxReceipt?.blockHash)
    console.log("> Manager deployed at", await manager.getAddress());
    // 等待 5 个区块确认
    console.log(`> Waiting for ${managerDeployTxReceipt?.confirmations} confirmations...`);
    await managerDeployTxReceipt?.wait(5);

    // 验证合约（仅在非本地网络执行）
    if (network.name !== "hardhat" && process.env.VERIFY === 'true') {
        console.log(">> Verifying Manager");
        await hre.run("verify:verify", {
            address: await manager.getAddress(),
            constructorArguments: [
                deployer.address,
                config.PancakeSwapV3.NonfungiblePositionManager
            ],
        });
    }


};

export default func;
func.tags = ["Manager"];
