import hre from "hardhat";
import { INonfungiblePositionManager__factory } from "../typechain-types";
import { parseUnits } from "ethers";

const MODULE = "initializeNewPool"

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  // Base Testnet
  // https://docs.uniswap.org/contracts/v3/reference/deployments/base-deployments
  const nonfungiblePositionManager = INonfungiblePositionManager__factory.connect("0x27F971cb582BF9E50F397e4d29a5C7A34f11faA2", deployer);
  const tx = await nonfungiblePositionManager.createAndInitializePoolIfNecessary(
    "0x26ce00101c6F692Fa0394ea9B8bC818B6A682B22",
    "0xDAacF8678cf731609EeEdDEE41E7C71062Bff232",
    "3000",
    "79228162514264337593543950336",
    {
      gasLimit: 10000000,
      gasPrice: parseUnits("1", "gwei"),
    }
  )
  console.log("tx", tx.hash)
  await tx.wait()
  console.log("Pool created and initialized")
}

main().catch(console.error);