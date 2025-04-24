import {
  time,
  loadFixture,
  mine,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre, { ethers, ignition } from "hardhat";
import ManagerModule from "../../ignition/modules/Manager";
import { Manager__factory, UserVault__factory, UserVaultFactory__factory, UserVaultV2__factory } from "../../typechain-types";
import { IERC20__factory } from "../../typechain-types";
import StrategiesModule from "../../ignition/modules/Strategies";

// describe("Manager", function () {
//   // We define a fixture to reuse the same setup in every test.
//   // We use loadFixture to run this setup once, snapshot that state,
//   // and reset Hardhat Network to that snapshot in every test.
//   async function deployManagerFixture() {
//     const { manager } = await ignition.deploy(ManagerModule, {
//       parameters: {
//         ManagerModule: {
//           owner: "0x60838459D97C736A7BB5Ba28d68022aDc361258C",
//           user: "0x60838459D97C736A7BB5Ba28d68022aDc361258C",
//           nftPositionManager: "0x427bF5b37357632377eCbEC9de3626C71A5396c1",
//           factory: "0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865",
//           router: "0x1b81D678ffb9C0263b24A97847620C99d213eB14"
//         }
//       }
//     });
//     return { manager };
//   }

//   async function deployStrategyFixture() {
//     const { mintStrategy, decreaseLiquidityStrategy, addBaseTokenOnlyStrategy, addBaseTokenOnlyWithCalculateStrategy } = await ignition.deploy(StrategiesModule, {
//       parameters: {
//         StrategiesModule: {
//           positionManager: "0x427bF5b37357632377eCbEC9de3626C71A5396c1",
//           factory: "0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865",
//           router: "0x1b81D678ffb9C0263b24A97847620C99d213eB14"
//         }
//       }
//     });
//     return { mintStrategy, decreaseLiquidityStrategy, addBaseTokenOnlyStrategy, addBaseTokenOnlyWithCalculateStrategy };
//   }

//   async function deployUserVaultFixture() {
//     const { manager } = await loadFixture(deployManagerFixture);

//     const address = "0x60838459D97C736A7BB5Ba28d68022aDc361258C";
//     await hre.network.provider.request({
//       method: "hardhat_impersonateAccount",
//       params: [address],
//     });
//     const user = await hre.ethers.getSigner(address);

//     console.log(await manager.getAddress(), user.address);
//     const managerContract = Manager__factory.connect(await manager.getAddress(), user);
//     await managerContract.createUserVault();
//     return { managerContract, user };
//   }

//   describe("Deployment", function () {
//     it("Should set the right user vault", async function () {
//       const { managerContract, user } = await loadFixture(deployUserVaultFixture);
//       const userVault = await managerContract.userVaults(user.address);
//       expect(userVault).to.not.equal(hre.ethers.ZeroAddress);
//       console.log(userVault);
//     });
//   });

//   describe("Mint", function () {
//     it("Should mint", async function () {
//       const { managerContract, user } = await loadFixture(deployUserVaultFixture);
//       const { mintStrategy } = await loadFixture(deployStrategyFixture);

//       const token0 = IERC20__factory.connect("0x22D873Ce502a424c7909f1B950597b39F36b6608", user);
//       const token1 = IERC20__factory.connect("0xaB1a4d4f1D656d2450692D237fdD6C7f9146e814", user);
//       const mintParams = {
//         token0: "0x22D873Ce502a424c7909f1B950597b39F36b6608",
//         token1: "0xaB1a4d4f1D656d2450692D237fdD6C7f9146e814",
//         fee: 2500,
//         tickLower: -46050,
//         tickUpper: 46050,
//         amount0Desired: hre.ethers.parseEther("10000"),
//         amount1Desired: hre.ethers.parseEther("10000"),
//         amount0Min: 0,
//         amount1Min: 0,
//         recipient: user.address,
//         deadline: 0,
//       };
//       const encodedParams = hre.ethers.AbiCoder.defaultAbiCoder().encode(
//         [
//           'tuple(address token0, address token1, uint24 fee, int24 tickLower, int24 tickUpper, uint256 amount0Desired, uint256 amount1Desired, uint256 amount0Min, uint256 amount1Min, address recipient, uint256 deadline)'
//         ],
//         [mintParams]
//       );
//       await managerContract.work(0, await mintStrategy.getAddress(), encodedParams);
//     });
//   });
// });

describe("UserVault Proxy System", function () {
  async function deploySystemFixture() {
    // Deploy the initial system
    const [owner] = await hre.ethers.getSigners();

    // Deploy initial UserVault implementation
    const userVaultImpl = await hre.ethers.deployContract("UserVault");

    // Deploy UserVaultFactory (Beacon)
    const userVaultFactory = await hre.ethers.deployContract("UserVaultFactory", [
      await userVaultImpl.getAddress(),
      owner.address
    ]);

    // Deploy Manager
    const manager = await hre.ethers.deployContract("Manager");

    await manager.initialize(
      owner.address,
      await userVaultFactory.getAddress()
    );

    return {
      manager,
      userVaultFactory,
      userVaultImpl,
      owner
    };
  }

  describe("Deployment and Upgrade", function () {
    it("Should deploy the system correctly", async function () {
      const { manager, userVaultFactory, userVaultImpl } = await loadFixture(deploySystemFixture);

      // Verify UserVaultFactory has correct implementation
      expect(await userVaultFactory.implementation()).to.equal(
        await userVaultImpl.getAddress()
      );
    });

    it("Should create a user vault correctly", async function () {
      const { manager, userVaultFactory } = await loadFixture(deploySystemFixture);
      const [owner] = await hre.ethers.getSigners();

      // Create user vault
      await manager.createUserVault();

      // Get user vault address
      const userVaultAddress = await manager.userVaults(owner.address);
      expect(userVaultAddress).to.not.equal(hre.ethers.ZeroAddress);

      // Verify user vault was initialized correctly
      const userVault = UserVault__factory.connect(userVaultAddress, owner);
      expect(await userVault.user()).to.equal(owner.address);
      expect(await userVault.manager()).to.equal(await manager.getAddress());
    });

    it("Should upgrade all user vaults", async function () {
      const { manager, userVaultFactory, owner } = await loadFixture(deploySystemFixture);

      // Create a user vault
      await manager.createUserVault();
      const userVaultAddress = await manager.userVaults(owner.address);

      // Deploy new implementation
      const userVaultV2 = await hre.ethers.deployContract("UserVaultV2");

      // Upgrade the beacon
      await userVaultFactory.upgradeTo(await userVaultV2.getAddress());

      // Verify the implementation was updated
      expect(await userVaultFactory.implementation()).to.equal(
        await userVaultV2.getAddress()
      );

      const userVault = UserVaultV2__factory.connect(userVaultAddress, owner);
      expect(await userVault.version()).to.equal(2);

      // Verify the user vault is still working with new implementation
      expect(await userVault.user()).to.equal(owner.address);
      expect(await userVault.manager()).to.equal(await manager.getAddress());
    });

    it("Should fail to upgrade from non-owner", async function () {
      const { userVaultFactory } = await loadFixture(deploySystemFixture);
      const [_, nonOwner] = await hre.ethers.getSigners();

      // Deploy new implementation
      const UserVaultV2 = await hre.ethers.getContractFactory("UserVault");
      const newImplementation = await UserVaultV2.deploy();

      // Attempt to upgrade from non-owner should fail
      await expect(
        userVaultFactory.connect(nonOwner).upgradeTo(await newImplementation.getAddress())
      ).revertedWithCustomError(userVaultFactory, "OwnableUnauthorizedAccount");
    });
  });
});
