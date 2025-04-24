import hre from "hardhat";
import { parseUnits } from "ethers";
import { INonfungiblePositionManager__factory } from "../typechain-types";
import { getDeployedAddressByModule } from "./utils/address";

const TokenMODULE = "MockTokenModule"

async function main() {
    const [deployer] = await hre.ethers.getSigners()
    const chainId = hre.network.config.chainId!

    const token0Addr = getDeployedAddressByModule(TokenMODULE, "MockToken0", chainId)
    const token1Addr = getDeployedAddressByModule(TokenMODULE, "MockToken1", chainId)

    // Base Testnet
    // https://docs.uniswap.org/contracts/v3/reference/deployments/base-deployments
    const nonfungiblePositionManager = INonfungiblePositionManager__factory.connect("0x27F971cb582BF9E50F397e4d29a5C7A34f11faA2", deployer)
    const tx = await nonfungiblePositionManager.createAndInitializePoolIfNecessary(
        token0Addr,
        token1Addr,
        "3000",
        "79228162514264337593543950336",
        {
            gasLimit: 10000000,
            gasPrice: parseUnits("1", "gwei")
        })
    console.log("tx", tx.hash)
    await tx.wait()
    console.log("Pool created and initialized")
}
main().catch(console.error);