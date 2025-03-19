// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IManager} from "../../contracts/interfaces/IManager.sol";
import {INonfungiblePositionManager} from "../../contracts/interfaces/uniswapV3/periphery/INonfungiblePositionManager.sol";
import {UserVaultFactory} from "../../contracts/UserVaultFactory.sol";
import {Manager} from "../../contracts/Manager.sol";
import {MockToken} from "../../contracts/test/MockToken.sol";
import {UserVault} from "../../contracts/UserVault.sol";
import {Position} from "../../contracts/interfaces/IUserVault.sol";
import {StrategyAddBaseTokenOnlyWithCalculateParam, PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate} from "../../contracts/strategies/pancakeswapV3/PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate.sol";
import {UniswapV3BaseSepoliaConfig} from "./config/UniswapV3BaseSepoliaConfig.sol";
import {EnvConfig} from "./config/EnvConfig.sol";
import {TickMath} from "../../contracts/libraries/TickMath.sol";

contract UniswapV3StrategiesTest is Test {
    // Contracts
    Manager public manager;
    UserVaultFactory public userVaultFactory;
    PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate
        public addBaseTokenOnlyWithCalculateStrategy;

    // Mock tokens
    MockToken public tokenA;
    MockToken public tokenB;

    // Token Path, assert the order of the tokens
    address public token0;
    address public token1;

    // Users
    address public user;
    address public deployer;

    // Constants
    uint256 constant INITIAL_MINT_AMOUNT = 1_000_000 ether;

    function setUp() public {
        // Fork the Base Sepolia testnet
        string memory BASE_SEPOLIA_RPC = vm.envString("BASE_SEPOLIA_RPC");
        uint256 baseSepoliaFork = vm.createFork(BASE_SEPOLIA_RPC);
        vm.selectFork(baseSepoliaFork);

        // Setup accounts
        deployer = address(this);
        user = makeAddr("user");
        vm.deal(user, 100 ether);

        // Deploy mock tokens with name, symbol, decimals, and owner
        tokenA = new MockToken("Token A", "TA", 18, deployer);
        tokenB = new MockToken("Token B", "TB", 18, deployer);

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
        addBaseTokenOnlyWithCalculateStrategy = new PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate();

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
        INonfungiblePositionManager(positionManager)
            .createAndInitializePoolIfNecessary(
                token0,
                token1,
                3000,
                79228162514264337593543950336
            );
    }

    function testAddBaseTokenOnly() public {
        // Skip test if we're not on a fork
        if (vm.activeFork() == 0) {
            return;
        }

        // Switch to user perspective
        vm.startPrank(user);

        // Create user vault if not exists
        address userVault = manager.userVaults(user);
        if (userVault == address(0)) {
            manager.createUserVault();
            userVault = manager.userVaults(user);
        }

        // Approve tokens to the vault
        tokenA.approve(userVault, INITIAL_MINT_AMOUNT);
        tokenB.approve(userVault, INITIAL_MINT_AMOUNT);

        address baseToken = token0;
        address farmingToken = token1;

        // Prepare strategy parameters
        StrategyAddBaseTokenOnlyWithCalculateParam
            memory params = StrategyAddBaseTokenOnlyWithCalculateParam({
                baseToken: baseToken,
                farmingToken: farmingToken,
                totalAmount:  777 ether,
                fee: 3000,
                tickLower: -46080,
                tickUpper: 46080,
                amount0Min: 0,
                amount1Min: 0,
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
            uint8(1),
            "Position type should be 1 (V3_LP)"
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
            0
        );

        assertEq(
            tokenB.balanceOf(address(addBaseTokenOnlyWithCalculateStrategy)),
            0
        );

        vm.stopPrank();
    }
}
