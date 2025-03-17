// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IManager} from "../../contracts/interfaces/IManager.sol";
import {UserVault} from "../../contracts/UserVault.sol";
import {Position} from "../../contracts/interfaces/IUserVault.sol";
import {StrategyAddBaseTokenOnlyWithCalculateParam, PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate} from "../../contracts/strategies/pancakeswapV3/PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate.sol";

import {PancakeSwapV3Config} from "./config/PancakeSwapV3Config.sol";
import {EnvConfig} from "./config/EnvConfig.sol";

contract PCSV3StrategiesAddBaseTokenTest is Test {
    IManager constant manager = IManager(PancakeSwapV3Config.Manager);
    IERC20 constant token0 = IERC20(PancakeSwapV3Config.Token0);
    IERC20 constant token1 = IERC20(PancakeSwapV3Config.Token1);

    PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate
        internal strategyAddBaseTokenOnly;

    address[] public actors;
    uint16 private constant NUM_ACTORS = 10;
    address internal currentActor;

    modifier useActor(uint256 actorIndexSeed) {
        currentActor = actors[bound(actorIndexSeed, 0, actors.length - 1)];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    function setUp() public {
        EnvConfig.useBscTestnet(vm);

        address owner = makeAddr("owner");
        vm.startPrank(owner);

        strategyAddBaseTokenOnly = PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate(
            0x175871F6f9B29cfb9BedD4FddE1C5feCAfC05cA5
        );

        // strategyAddBaseTokenOnly = new PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate();
        // strategyAddBaseTokenOnly.initialize(
        //     PancakeSwapV3Config.PancakeV3Factory,
        //     PancakeSwapV3Config.SwapRouter,
        //     PancakeSwapV3Config.NonfungiblePositionManager
        // );

        for (uint16 i = 0; i < NUM_ACTORS; i++) {
            address user = makeAddr(string(abi.encodePacked("user_", i)));
            deal(address(token0), user, 100 ether);
            deal(address(token1), user, 100 ether);
            actors.push(user);
        }
    }

    function creatUserValut(address user) internal returns (address) {
        address userVault = manager.userVaults(user);
        if (userVault != address(0)) {
            return userVault;
        }
        manager.createUserVault();
        userVault = manager.userVaults(user);

        vm.startPrank(strategyAddBaseTokenOnly.owner());
        address[] memory vaults = new address[](1);
        vaults[0] = manager.userVaults(user);
        vm.startPrank(user);
        return userVault;
    }

    function testWork(uint256 actorIndexSeed) public useActor(actorIndexSeed) {
        uint24 fee = 2500;
        uint256 totalAmount = 1 ether;
        int24 tickLower = -25050;
        int24 tickUpper = 25050;

        UserVault userVault = UserVault(creatUserValut(currentActor));

        console.log("userVault: ", address(userVault));

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
        vm.startPrank(currentActor);

        uint256 nextPosId = userVault.nextPositionId();
        console.log(nextPosId);
        manager.work(0, address(strategyAddBaseTokenOnly), abi.encode(params));

        Position memory pos = userVault.positions(nextPosId);
        uint256 tokenID = abi.decode(pos.data, (uint256));
        console.log("posType: ", pos.posType);
        console.log("tokenId: ", tokenID);
    }
}
