// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IManager} from "../../contracts/interfaces/IManager.sol";
import {Manager} from "../../contracts/Manager.sol";
import {PancakeSwapV3Config} from "./config/PancakeSwapV3Config.sol";
import {EnvConfig} from "./config/EnvConfig.sol";

contract ManagerTest is Test {
    IManager constant manager = IManager(PancakeSwapV3Config.Manager);

    address[] public actors;
    address internal currentActor;

    modifier useActor(uint256 actorIndexSeed) {
        currentActor = actors[bound(actorIndexSeed, 0, actors.length - 1)];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    function setUp() public {
        EnvConfig.useBscTestnet(vm);
    }

    function testCreateVault() public {
        address sender = msg.sender;
        vm.startPrank(sender);
        manager.createUserVault(address(0));
        address vaultAddress = manager.userVaults(sender);
        assertTrue(vaultAddress != address(0), "Vault creation failed");
    }

    function testRecreateVault() public {
        address sender = msg.sender;
        vm.startPrank(sender);
        manager.createUserVault(address(0));

        vm.expectRevert();
        manager.createUserVault(address(0));
    }
}
