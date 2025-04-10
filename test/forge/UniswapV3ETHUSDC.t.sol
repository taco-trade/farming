// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IV3SwapRouter} from "../../contracts/interfaces/uniswapV3/periphery/IV3SwapRouter.sol";
import {IManager} from "../../contracts/interfaces/IManager.sol";
import {INonfungiblePositionManager} from "../../contracts/interfaces/uniswapV3/periphery/INonfungiblePositionManager.sol";
import {UserVaultFactory} from "../../contracts/UserVaultFactory.sol";
import {Manager} from "../../contracts/Manager.sol";
import {MockToken} from "../../contracts/test/MockToken.sol";
import {UserVault} from "../../contracts/UserVault.sol";
import {Position} from "../../contracts/interfaces/IUserVault.sol";
import {StrategyAddBaseTokenOnlyWithCalculateParam, UniswapV3StrategyAddBaseTokenOnly} from "../../contracts/strategies/uniswapV3/UniswapV3StrategyAddBaseTokenOnly.sol";
import {UniswapV3BaseConfig} from "./config/UniswapV3BaseConfig.sol";
import {EnvConfig} from "./config/EnvConfig.sol";
import {TickMath} from "../../contracts/libraries/TickMath.sol";

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

interface USDC is IERC20 {
    function mint(address to, uint256 amount) external;
}

contract UniswapV3ETHUSDC is Test {
    // Contracts
    Manager public manager;
    UserVaultFactory public userVaultFactory;
    UniswapV3StrategyAddBaseTokenOnly
        public addBaseTokenOnlyWithCalculateStrategy;

    // Token Path, assert the order of the tokens
    address public token0 = 0x4200000000000000000000000000000000000006;
    address public token1 = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // Users
    address public user;
    address public deployer;

    // Constants
    uint256 constant INITIAL_MINT_AMOUNT = 1_000_000 ether;

    function setUp() public {
        // Fork the Base Sepolia testnet
        string memory BASE_RPC = vm.envString("BASE_RPC");
        uint256 baseFork = vm.createFork(BASE_RPC, 28004465);
        vm.selectFork(baseFork);

        // Setup accounts
        deployer = address(this);
        user = makeAddr("user");
        vm.deal(user, 1000 ether);

        vm.startPrank(user);
        IWETH(token0).deposit{value: 1000 ether}();
        IERC20(token0).approve(UniswapV3BaseConfig.SwapRouter, 1000 ether);
        IV3SwapRouter(UniswapV3BaseConfig.SwapRouter).exactInput(
            IV3SwapRouter.ExactInputParams(
                abi.encodePacked(token0, uint24(500), token1),
                user,
                50 ether,
                0
            )
        );
        vm.stopPrank();

        // Deploy main contracts
        // First deploy UserVault implementation
        UserVault userVaultImpl = new UserVault();

        // Then factory with implementation and owner
        userVaultFactory = new UserVaultFactory(
            address(userVaultImpl),
            deployer
        );

        // Then manager
        manager = new Manager();
        manager.initialize(deployer, address(userVaultFactory));

        // Deploy the strategy
        addBaseTokenOnlyWithCalculateStrategy = new UniswapV3StrategyAddBaseTokenOnly();

        // Initialize strategy with real PancakeSwap V3 contracts
        addBaseTokenOnlyWithCalculateStrategy.initialize(
            UniswapV3BaseConfig.Factory,
            UniswapV3BaseConfig.SwapRouter,
            UniswapV3BaseConfig.NonfungiblePositionManager
        );

        // Whitelist the strategy in the manager
        address[] memory strategies = new address[](1);
        strategies[0] = address(addBaseTokenOnlyWithCalculateStrategy);
        manager.setApprovedStrategies(strategies, true);

        // Whitelist the pool in the manager
        bytes32[] memory pools = new bytes32[](1);
        pools[0] = keccak256(abi.encodePacked(token0, token1, uint24(3000)));
        manager.setApprovedPools(pools, true);
    }

    function testAddBaseTokenOnly() public {
        // Use default parameters
        uint256 amount = 50000000;
        int24 tickLower = -200040;
        int24 tickUpper = -199860;

        _testAddBaseTokenWithParams(amount, tickLower, tickUpper);
    }

    // forge-config: default.fuzz.runs = 10
    function _testAddBaseTokenOnlyFuzzed(
        uint256 amount,
        int24 tickLowerMultiplier,
        int24 tickUpperMultiplier
    ) public {
        // Bound the input parameters to reasonable values
        amount = bound(amount, 0.01 ether, 50 ether);

        // Keep ticks within reasonable ranges and ensure they're multiples of tickSpacing (60 for 3000 fee tier)
        int24 tickSpacing = 60;
        int24 minTick = -887220;  // Min tick for Uniswap V3
        int24 maxTick = 887220;   // Max tick for Uniswap V3

        // Bound multipliers to create valid tick ranges
        tickLowerMultiplier = int24(bound(int24(tickLowerMultiplier), 1, 7000));
        tickUpperMultiplier = int24(bound(int24(tickUpperMultiplier), 1, 7000));

        // Calculate ticks ensuring they're multiples of tickSpacing
        int24 tickLower = (minTick / tickSpacing + tickLowerMultiplier) * tickSpacing;
        int24 tickUpper = (maxTick / tickSpacing - tickUpperMultiplier) * tickSpacing;

        // Ensure tickLower < tickUpper
        if (tickLower >= tickUpper) {
            int24 temp = tickLower;
            tickLower = tickUpper - tickSpacing * 10;  // Ensure at least some gap
            tickUpper = temp + tickSpacing * 10;
        }

        // Ensure we're within valid ranges
        tickLower = tickLower < minTick ? minTick : tickLower;
        tickUpper = tickUpper > maxTick ? maxTick : tickUpper;

        _testAddBaseTokenWithParams(amount, tickLower, tickUpper);
    }

    function _testAddBaseTokenWithParams(
        uint256 amount,
        int24 tickLower,
        int24 tickUpper
    ) internal {
        // Switch to user perspective
        vm.startPrank(user);

        // Create user vault if not exists
        address userVault = manager.userVaults(user);
        if (userVault == address(0)) {
            manager.createUserVault(address(0));
            userVault = manager.userVaults(user);
        }

        // Approve tokens to the vault
        IERC20(token0).approve(userVault, INITIAL_MINT_AMOUNT);
        IERC20(token1).approve(userVault, INITIAL_MINT_AMOUNT);

        address baseToken = token1;
        address farmingToken = token0;

        // Prepare strategy parameters
        StrategyAddBaseTokenOnlyWithCalculateParam
            memory params = StrategyAddBaseTokenOnlyWithCalculateParam({
                baseToken: baseToken,
                farmingToken: farmingToken,
                totalAmount: amount,
                fee: 500,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Min: 0,
                amount1Min: 0,
                swapPath: abi.encodePacked(
                    baseToken,
                    uint24(500),
                    farmingToken
                )
            });

        // Encode strategy parameters
        bytes memory encodedParams = abi.encode(true, params);

        // Call work function to execute the strategy
        manager.work(
            userVault,
            0,
            address(addBaseTokenOnlyWithCalculateStrategy),
            encodedParams
        );

        // Verify the position was created
        UserVault vault = UserVault(userVault);
        Position memory position = vault.positions(1);

        // Check position type
        assertEq(
            position.posType,
            uint8(0),
            "Position type should be 0 (V3_LP)"
        );

        // Decode position data
        (
            uint256 tokenId,
            address posToken0,
            address posToken1,
            uint24 posFee
        ) = abi.decode(position.data, (uint256, address, address, uint24));

        // Verify position data
        assertTrue(tokenId > 0, "Token ID should be greater than 0");
        assertEq(posToken0, token0, "Token0 should match");
        assertEq(posToken1, token1, "Token1 should match");
        assertEq(posFee, 500, "Fee should match");

        // // Balance of the strategy should be 0
        assertEq(
            IERC20(token0).balanceOf(address(addBaseTokenOnlyWithCalculateStrategy)),
            0,
            "Token A balance should be 0"
        );

        assertEq(
            IERC20(token1).balanceOf(address(addBaseTokenOnlyWithCalculateStrategy)),
            0,
            "Token B balance should be 0"
        );

        vm.stopPrank();
    }
}
