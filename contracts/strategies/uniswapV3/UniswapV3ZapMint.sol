// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {IStrategy} from "../../interfaces/IStrategy.sol";
import {IUserVault, Position} from "../../interfaces/IUserVault.sol";
import {IV3SwapRouter} from "../../interfaces/uniswapV3/periphery/IV3SwapRouter.sol";
import {INonfungiblePositionManager} from "../../interfaces/uniswapV3/periphery/INonfungiblePositionManager.sol";
import "../../libraries/LiqMath.sol";
import "../../libraries/TickMath.sol";
import "../../interfaces/uniswapV3/core/IUniswapV3Factory.sol";
import "../../interfaces/uniswapV3/core/IUniswapV3Pool.sol";

struct StrategyZapMintParam {
    address token0;
    address token1;
    uint256 amount0;
    uint256 amount1;
    uint24 fee;
    int24 tickLower;
    int24 tickUpper;
    uint256 sqrtPriceX96;
    uint256 slippage; // 1_000_000 = 100%
    uint256 priceSlippage; // 1_000_000 = 100%
    bytes token0SwapPath;
    bytes token1SwapPath;
    bool userFund;
}

contract UniswapV3ZapMint is 
    IStrategy,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    address public factory;
    address public router;
    address public positionManager;

    error PositionAlreadyExists();
    error InvalidToken();
    error InvalidAmount();
    error InvalidPriceSlippage();

    event Mint(
        address indexed vault,
        uint256 indexed positionID,
        uint256 indexed tokenID,
        address token0,
        address token1,
        uint128 liquidity,
        uint256 token0Amount,
        uint256 token1Amount
    );

    function initialize(
        address _factory,
        address _router,
        address _positionManager
    ) external initializer {
        OwnableUpgradeable.__Ownable_init(msg.sender);

        factory = _factory;
        router = _router;
        positionManager = _positionManager;
    }

    function execute(
        address _caller,
        uint256 _positionID,
        bytes calldata data
    ) 
        external 
        override 
        nonReentrant 
        returns (uint8 posType, bytes memory posData) 
    {
        // Decode parameters
        StrategyZapMintParam memory params = abi.decode(
            data,
            (StrategyZapMintParam)
        );

        // Validate parameters
        _validateParams(_caller, _positionID, params);

        // Request funds
        _requestFunds(params);

        // Calculate swap amounts and mint position
        (
            uint256 tokenID,
            uint128 liquidity,
            uint256 token0Amount,
            uint256 token1Amount
        ) = _swapAndMint(params);

        // Refund any remaining tokens
        _refundTokens(params.token0, params.token1, params.userFund);

        emit Mint(
            msg.sender,
            _positionID,
            tokenID,
            params.token0,
            params.token1,
            liquidity,
            token0Amount,
            token1Amount
        );

        return (
            uint8(PositionType.V3_LP),
            abi.encode(
                V3Position({
                    tokenId: tokenID,
                    token0: params.token0,
                    token1: params.token1,
                    fee: params.fee
                })
            )
        );
    }

    function _validateParams(
        address _caller,
        uint256 _positionID,
        StrategyZapMintParam memory params
    ) internal view {
        Position memory _position = IUserVault(msg.sender).positions(
            _positionID
        );
        if (_position.data.length != 0) revert PositionAlreadyExists();

        if (
            params.token0 == address(0) ||
            params.token1 == address(0) ||
            params.token0 > params.token1
        ) revert InvalidToken();
        if (params.amount0 == 0 && params.amount1 == 0) revert InvalidAmount();

        // Validate caller is authorized
        address _agent = IUserVault(msg.sender).agent();
        if (_caller != IUserVault(msg.sender).user() && _caller != _agent) {
            revert NotAuthorized();
        }

        if (_caller == _agent && params.userFund) {
            revert NotAuthorized();
        }
    }

    function _requestFunds(StrategyZapMintParam memory params) internal {
        if (params.userFund) {
            IUserVault(msg.sender).requestFundsFromUser(
                params.token0,
                params.amount0
            );
            IUserVault(msg.sender).requestFundsFromUser(
                params.token1,
                params.amount1
            );
        } else {
            IUserVault(msg.sender).requestFunds(params.token0, params.amount0);
            IUserVault(msg.sender).requestFunds(params.token1, params.amount1);
        }
    }

    function _refundTokens(address token0, address token1, bool userFund) internal {
        address refundAddr = userFund
            ? IUserVault(msg.sender).user()
            : msg.sender;
        SafeERC20.safeTransfer(
            IERC20(token0),
            refundAddr,
            IERC20(token0).balanceOf(address(this))
        );
        SafeERC20.safeTransfer(
            IERC20(token1),
            refundAddr,
            IERC20(token1).balanceOf(address(this))
        );
    }

    function _swapAndMint(
        StrategyZapMintParam memory params
    )
        internal
        returns (
            uint256 tokenID,
            uint128 liquidity,
            uint256 token0Amount,
            uint256 token1Amount
        )
    {
        // Calculate and perform optimal swaps
        _calculateAndPerformSwaps(params);

        uint256 t0Amount = IERC20(params.token0).balanceOf(address(this));
        uint256 t1Amount = IERC20(params.token1).balanceOf(address(this));

        // Prepare mint parameters
        INonfungiblePositionManager.MintParams
            memory mintParams = INonfungiblePositionManager.MintParams(
                params.token0,
                params.token1,
                params.fee,
                params.tickLower,
                params.tickUpper,
                t0Amount,
                t1Amount,
                LiqMath.getMinAmount(t0Amount, params.slippage),
                LiqMath.getMinAmount(t1Amount, params.slippage),
                address(msg.sender),
                block.timestamp
            );

        // Approve position manager to spend tokens
        SafeERC20.forceApprove(
            IERC20(params.token0),
            positionManager,
            mintParams.amount0Desired
        );
        SafeERC20.forceApprove(
            IERC20(params.token1),
            positionManager,
            mintParams.amount1Desired
        );

        // Mint position
        (
            tokenID,
            liquidity,
            token0Amount,
            token1Amount
        ) = INonfungiblePositionManager(positionManager).mint(mintParams);

        return (tokenID, liquidity, token0Amount, token1Amount);
    }

    function _calculateAndPerformSwaps(
        StrategyZapMintParam memory params
    ) internal {
        // Get pool info
        address poolAddr = IUniswapV3Factory(factory).getPool(
            params.token0,
            params.token1,
            params.fee
        );

        // Get current price and tick bounds
        (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(poolAddr).slot0();
        // Validate price slippage
        if (!LiqMath.validatePriceSlippage(params.sqrtPriceX96, sqrtPriceX96, params.priceSlippage)) revert InvalidPriceSlippage();

        uint160 sqrtPriceLowerX96 = TickMath.getSqrtRatioAtTick(
            params.tickLower
        );
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtRatioAtTick(
            params.tickUpper
        );

        // Calculate optimal amounts based on price range
        (bool isToken0, uint256 swapAmount) = LiqMath.getSwapAmount(
            sqrtPriceX96,
            sqrtPriceLowerX96,
            sqrtPriceUpperX96,
            params.amount0,
            params.amount1
        );

        // Perform swaps if needed
        if (swapAmount > 0) {
            if (isToken0) {
                _swap(params.token0, swapAmount, params.token0SwapPath);
            } else {
                _swap(params.token1, swapAmount, params.token1SwapPath);
            }
        }
    }

    function _swap(
        address _token,
        uint256 _amount,
        bytes memory _swapPath
    ) internal {
        SafeERC20.forceApprove(IERC20(_token), router, _amount);
        IV3SwapRouter(router).exactInput(
            IV3SwapRouter.ExactInputParams(_swapPath, address(this), _amount, 0)
        );
    }
}
