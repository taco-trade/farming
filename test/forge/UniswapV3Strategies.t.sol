// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IManager} from "../../contracts/interfaces/IManager.sol";
import {INonfungiblePositionManager} from "../../contracts/interfaces/uniswapV3/periphery/INonfungiblePositionManager.sol";
import {UserVaultFactory} from "../../contracts/UserVaultFactory.sol";
import {Manager} from "../../contracts/Manager.sol";
import {MockToken} from "../../contracts/test/MockToken.sol";
import {UserVault} from "../../contracts/UserVault.sol";
import {Position} from "../../contracts/interfaces/IUserVault.sol";
import {StrategyAddBaseTokenOnlyWithCalculateParam, UniswapV3StrategyAddBaseTokenOnly} from "../../contracts/strategies/uniswapV3/UniswapV3StrategyAddBaseTokenOnly.sol";
import {UniswapV3BaseSepoliaConfig} from "./config/UniswapV3BaseSepoliaConfig.sol";
import {TickMath} from "../../contracts/libraries/TickMath.sol";

interface Pool {
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );
}

contract UniswapV3StrategiesTest is Test {
    // Contracts
    Manager public manager;
    UserVaultFactory public userVaultFactory;
    UniswapV3StrategyAddBaseTokenOnly
        public addBaseTokenOnlyWithCalculateStrategy;

    // Mock tokens
    MockToken public tokenA;
    MockToken public tokenB;

    // Token Path, assert the order of the tokens
    address public token0;
    address public token1;
    address public pool;

    // Users
    address public user;
    address public deployer;

    // Constants
    uint256 constant INITIAL_MINT_AMOUNT = 1_000_000 ether;

    function setUp() public {
        // Fork the Base Sepolia testnet
        string memory BASE_SEPOLIA_RPC = vm.envString("BASE_SEPOLIA_RPC");
        uint256 baseSepoliaFork = vm.createFork(BASE_SEPOLIA_RPC, 23329343);
        vm.selectFork(baseSepoliaFork);

        // Setup accounts
        deployer = address(this);
        user = makeAddr("user");
        vm.deal(user, 100 ether);

        // Deploy mock tokens with name, symbol, decimals, and owner
        tokenA = new MockToken("Token A", "TA", 18, deployer);
        tokenB = new MockToken("Token B", "TB", 6, deployer);

        // Sort tokens to maintain order
        (token0, token1) = address(tokenA) < address(tokenB)
            ? (address(tokenA), address(tokenB))
            : (address(tokenB), address(tokenA));

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
            UniswapV3BaseSepoliaConfig.Factory,
            UniswapV3BaseSepoliaConfig.SwapRouter,
            UniswapV3BaseSepoliaConfig.NonfungiblePositionManager
        );

        // Whitelist the strategy in the manager
        address[] memory strategies = new address[](1);
        strategies[0] = address(addBaseTokenOnlyWithCalculateStrategy);
        manager.setApprovedStrategies(strategies, true);

        // Whitelist the pool in the manager
        bytes32[] memory pools = new bytes32[](1);
        pools[0] = keccak256(abi.encodePacked(token0, token1, uint24(3000)));
        manager.setApprovedPools(pools, true);

        // Mint tokens to user
        tokenA.mint(user, INITIAL_MINT_AMOUNT);
        tokenB.mint(user, INITIAL_MINT_AMOUNT);

        // Create the pool if it doesn't exist
        // We are deploying mock tokens, so we need to ensure the pool exists
        // address factory = UniswapV3BaseSepoliaConfig.Factory;
        address positionManager = UniswapV3BaseSepoliaConfig
            .NonfungiblePositionManager;

        // Use a low-level call to create the pool through the factory
        pool =INonfungiblePositionManager(positionManager)
            .createAndInitializePoolIfNecessary(
                token0,
                token1,
                3000,
                1777828899773946460285413992955904
            );

        address lp = makeAddr("lp");
        tokenA.mint(lp, 1000000 ether);
        tokenB.mint(lp, 1000000 ether);
        vm.startPrank(lp);
        tokenA.approve(positionManager, type(uint256).max);
        tokenB.approve(positionManager, type(uint256).max);
        INonfungiblePositionManager(positionManager).mint(
            INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: 3000,
                tickLower: -46020,
                tickUpper: 46020,
                amount0Desired: 1000000 ether,
                amount1Desired: 1000000 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: lp,
                deadline: block.timestamp + 1000
            })
        );
        vm.stopPrank();
    }

    // forge-config: default.fuzz.runs = 200
    function testAddBaseTokenOnlyFuzzed(
        uint256 amount,
        int24 tickLowerMultiplier,
        int24 tickUpperMultiplier
    ) public {
        // Bound the input parameters to reasonable values
        amount = bound(amount, 0.01 ether, 10000 ether);

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
        tokenA.approve(userVault, INITIAL_MINT_AMOUNT);
        tokenB.approve(userVault, INITIAL_MINT_AMOUNT);

        address baseToken = token0;
        address farmingToken = token1;

        // Prepare strategy parameters
        (uint160 sqrtPriceX96, , , , , , ) = Pool(pool).slot0();
        StrategyAddBaseTokenOnlyWithCalculateParam
            memory params = StrategyAddBaseTokenOnlyWithCalculateParam({
                baseToken: baseToken,
                farmingToken: farmingToken,
                totalAmount: amount,
                fee: 3000,
                tickLower: tickLower,
                tickUpper: tickUpper,
                slippage: 90_0000,
                priceSlippage: 10_000,
                sqrtPriceX96: sqrtPriceX96,
                swapPath: abi.encodePacked(
                    baseToken,
                    uint24(3000),
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
        assertEq(posFee, 3000, "Fee should match");

        // Balance of the strategy should be 0
        assertEq(
            tokenA.balanceOf(address(addBaseTokenOnlyWithCalculateStrategy)),
            0,
            "Token A balance should be 0"
        );

        assertEq(
            tokenB.balanceOf(address(addBaseTokenOnlyWithCalculateStrategy)),
            0,
            "Token B balance should be 0"
        );

        vm.stopPrank();
    }
}
