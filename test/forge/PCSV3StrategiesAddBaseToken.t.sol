// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IManager} from "../../contracts/interfaces/IManager.sol";
import {UserVault} from "../../contracts/UserVault.sol";
import {StrategyAddBaseTokenOnlyWithCalculateParam, PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate} from "../../contracts/strategies/pancakeswapV3/PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate.sol";

contract PCSV3StrategiesAddBaseTokenTest is Test {
    uint256 bsctestnetFork;
    IManager constant manager =
        IManager(0x40a7DeB1d6CD47b982B18ca939b89C3b5C93705E);
    PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate constant strategyAddBaseTokenOnly =
        PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate(
            0x175871F6f9B29cfb9BedD4FddE1C5feCAfC05cA5
        );
    IERC20 constant token0 = IERC20(0xC25760C60fEC69175507e780790453014f360f73);
    IERC20 constant token1 = IERC20(0x848FfB71A5Fe748f895Ed94ceE4f84037c5d249A);

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

    function creatUserValut(address user) internal returns (address) {
        manager.createUserVault();
        address userVault = manager.userVaults(user);

        vm.startPrank(strategyAddBaseTokenOnly.owner());
        address[] memory vaults = new address[](1);
        vaults[0] = manager.userVaults(user);
        strategyAddBaseTokenOnly.setVaultsOk(vaults, true);
        vm.startPrank(user);
        return userVault;
    }

    function testWork() public {
        uint24 fee = 2500;
        uint256 totalAmount = 1 ether;
        int24 tickLower = -25050;
        int24 tickUpper = 25050;
        address sender = makeAddr("realUser");

        vm.startPrank(sender);
        address userVault = creatUserValut(sender);

        console.log("userVault: ", userVault);
        console.log("userVault is ok? ", strategyAddBaseTokenOnly.okVaults(userVault));

        deal(address(token0), sender, 100 ether);
        deal(address(token1), sender, 100 ether);
        token0.approve(address(userVault), 100 ether);
        token1.approve(address(userVault), 100 ether);

        StrategyAddBaseTokenOnlyWithCalculateParam
            memory params = StrategyAddBaseTokenOnlyWithCalculateParam(
                address(token0),
                address(token1),
                totalAmount,
                fee,
                tickLower,
                tickUpper,
                0, // amount0Min
                0, // amount1Min
                abi.encodePacked(token0, fee, token1)
            );
        vm.startPrank(sender);
        manager.work(0, address(strategyAddBaseTokenOnly), abi.encode(params));
    }
}
