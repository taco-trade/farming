// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IManager} from "../../contracts/interfaces/IManager.sol";
import {Manager} from "../../contracts/Manager.sol";
import {PancakeSwapV3Config} from "./config/PancakeSwapV3Config.sol";

contract ManagerTest is Test {
    uint256 bsctestnetFork;
    IManager constant manager =
        IManager(0x40a7DeB1d6CD47b982B18ca939b89C3b5C93705E);

    address[] public actors;
    address internal currentActor;

    modifier useActor(uint256 actorIndexSeed) {
        currentActor = actors[bound(actorIndexSeed, 0, actors.length - 1)];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    function setUp() public {
        string memory BSCTESTNET_RPC_URL = vm.envString("BSC_TESTNET_RPC");
        bsctestnetFork = vm.createFork(BSCTESTNET_RPC_URL);
        vm.selectFork(bsctestnetFork);
    }

    function testCreateVault() public {
        address sender = msg.sender;
        vm.startPrank(sender);
        manager.createUserVault();
        address vaultAddress = manager.userVaults(sender);
        assertTrue(vaultAddress != address(0), "Vault creation failed");
    }

    function testRecreateVault() public {
        address sender = msg.sender;
        vm.startPrank(sender);
        manager.createUserVault();

        vm.expectRevert();
        manager.createUserVault();
    }
}
