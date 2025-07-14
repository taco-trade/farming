// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {IStrategy} from "../../interfaces/IStrategy.sol";
import {IUserVault, Position} from "../../interfaces/IUserVault.sol";
import {IV3SwapRouter} from "../../interfaces/uniswapV3/periphery/IV3SwapRouter.sol";
import {INonfungiblePositionManager} from "../../interfaces/uniswapV3/periphery/INonfungiblePositionManager.sol";
import "../../libraries/LiqMath.sol";
import "../../libraries/TickMath.sol";
import "../../interfaces/uniswapV3/core/IUniswapV3Factory.sol";
import "../../interfaces/uniswapV3/core/IUniswapV3Pool.sol";

struct StrategyAddBaseTokenOnlyWithCalculateParam {
    address baseToken;
    address farmingToken;
    uint256 totalAmount;
    uint256 sqrtPriceX96;
    uint256 slippage; // 1_000_000 = 100%
    uint256 priceSlippage; // 1_000_000 = 100%
    uint24 fee;
    int24 tickLower;
    int24 tickUpper;
    bytes swapPath;
}

contract UniswapV3StrategyAddBaseTokenOnly is
    IStrategy,
    OwnableUpgradeable
{
    address public factory;
    address public router;
    address public positionManager;

    error PositionAlreadyExists();
    error InvalidToken();
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

    /// @dev Execute strategy. Take BaseToken. Return LP tokens.
    /// @param data Extra calldata information passed along to this strategy.
    function execute(
        address _caller,
        uint256 _positionID,
        bytes calldata data
    ) external override returns (uint8 posType, bytes memory posData) {
        // Decode parameters
        (
            bool _userFund,
            StrategyAddBaseTokenOnlyWithCalculateParam memory params
        ) = abi.decode(
                data,
                (bool, StrategyAddBaseTokenOnlyWithCalculateParam)
            );

        // Validate paramas and agent's behavior
        _validateParams(_caller, _userFund, _positionID, params);

        // Request funds
        _requestFunds(_userFund, params.baseToken, params.totalAmount);

        (
            uint256 tokenID,
            uint128 liquidity,
            uint256 token0Amount,
            uint256 token1Amount,
            address token0Addr,
            address token1Addr
        ) = _swapAndMint(params);

        // There may be tokens left in this contract
        _refundTokens(params.baseToken, params.farmingToken, _userFund);

        emit Mint(
            msg.sender,
            _positionID,
            tokenID,
            token0Addr,
            token1Addr,
            liquidity,
            token0Amount,
            token1Amount
        );

        return (
            uint8(PositionType.V3_LP),
            abi.encode(
                V3Position({
                    tokenId: tokenID,
                    token0: token0Addr,
                    token1: token1Addr,
                    fee: params.fee
                })
            )
        );
    }

    function _requestFunds(
        bool _userFund,
        address _baseToken,
        uint256 _totalAmount
    ) internal {
        if (_userFund) {
            IUserVault(msg.sender).requestFundsFromUser(
                _baseToken,
                _totalAmount
            );
        } else {
            IUserVault(msg.sender).requestFunds(_baseToken, _totalAmount);
        }
    }

    function _refundTokens(
        address baseToken,
        address farmingToken,
        bool userFund
    ) internal {
        address refundAddr = userFund
            ? IUserVault(msg.sender).user()
            : msg.sender;
        SafeERC20.safeTransfer(
            IERC20(baseToken),
            refundAddr,
            IERC20(baseToken).balanceOf(address(this))
        );
        SafeERC20.safeTransfer(
            IERC20(farmingToken),
            refundAddr,
            IERC20(farmingToken).balanceOf(address(this))
        );
    }

    function _validateAgent(
        address _caller,
        bool _userFund
    ) internal view returns (bool) {
        address _vault = msg.sender;
        if (_caller == IUserVault(_vault).user()) {
            return true;
        }

        if (_caller != IUserVault(_vault).agent()) {
            return false;
        }

        // Agent should not use user fund or pool is not approved
        if (_userFund) {
            return false;
        }

        return true;
    }

    function _calculateSwapAmount(
        address baseToken,
        address farmingToken,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint256 totalAmount,
        uint256 expectedSqrtPriceX96,
        uint256 priceSlippage
    )
        internal
        view
        returns (uint256 swapAmount, address token0Addr, address token1Addr)
    {
        address poolAddr = IUniswapV3Factory(factory).getPool(
            baseToken,
            farmingToken,
            fee
        );

        // token1/token0
        (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(poolAddr).slot0();

        // Validate price slippage
        if (!LiqMath.validatePriceSlippage(expectedSqrtPriceX96, sqrtPriceX96, priceSlippage)) revert InvalidPriceSlippage();

        uint160 sqrtPriceLowerX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        token0Addr = IUniswapV3Pool(poolAddr).token0();
        if (baseToken == token0Addr) {
            token1Addr = farmingToken;
            swapAmount = LiqMath.getToken0SwapAmount(
                sqrtPriceX96,
                sqrtPriceLowerX96,
                sqrtPriceUpperX96,
                totalAmount
            );
        } else {
            token1Addr = baseToken;
            swapAmount = LiqMath.getToken1SwapAmount(
                sqrtPriceX96,
                sqrtPriceLowerX96,
                sqrtPriceUpperX96,
                totalAmount
            );
        }
    }

    function _validateParams(
        address _caller,
        bool _userFund,
        uint256 _positionID,
        StrategyAddBaseTokenOnlyWithCalculateParam memory params
    ) internal view {
        Position memory _position = IUserVault(msg.sender).positions(
            _positionID
        );
        if (_position.data.length != 0) revert PositionAlreadyExists();

        if (params.baseToken == address(0)) revert InvalidToken();
        if (params.farmingToken == address(0)) revert InvalidToken();

        if (!_validateAgent(_caller, _userFund)) revert NotAuthorized();
    }

    function _swapAndMint(
        StrategyAddBaseTokenOnlyWithCalculateParam memory params
    )
        internal
        returns (
            uint256 tokenID,
            uint128 liquidity,
            uint256 token0Amount,
            uint256 token1Amount,
            address token0Addr,
            address token1Addr
        )
    {
        uint256 swapAmount;
        (swapAmount, token0Addr, token1Addr) = _calculateSwapAmount(
            params.baseToken,
            params.farmingToken,
            params.fee,
            params.tickLower,
            params.tickUpper,
            params.totalAmount,
            params.sqrtPriceX96,
            params.priceSlippage
        );

        uint256 baseAmount = params.totalAmount - swapAmount;
        uint256 farmingAmount = swapAmount;
        if (swapAmount > 0) {
            SafeERC20.forceApprove(
                IERC20(params.baseToken),
                router,
                swapAmount
            );
            farmingAmount = IV3SwapRouter(router).exactInput(
                IV3SwapRouter.ExactInputParams(
                    params.swapPath,
                    address(this),
                    swapAmount,
                    0
                )
            );
        }

        INonfungiblePositionManager.MintParams memory mintParams = _buildMintParams(
            token0Addr,
            token1Addr,
            baseAmount,
            farmingAmount,
            params
        );

        SafeERC20.forceApprove(
            IERC20(mintParams.token0),
            positionManager,
            mintParams.amount0Desired
        );
        SafeERC20.forceApprove(
            IERC20(mintParams.token1),
            positionManager,
            mintParams.amount1Desired
        );

        (tokenID, liquidity, token0Amount, token1Amount) = INonfungiblePositionManager(positionManager).mint(
            mintParams
        );

        return (
            tokenID,
            liquidity,
            token0Amount,
            token1Amount,
            token0Addr,
            token1Addr
        );
    }

    function _buildMintParams(
        address token0Addr,
        address token1Addr,
        uint256 baseAmount,
        uint256 farmingAmount,
        StrategyAddBaseTokenOnlyWithCalculateParam memory params
    ) internal view returns (INonfungiblePositionManager.MintParams memory) {
        uint256 t0Amount;
        uint256 t1Amount;
        uint256 t0Min;
        uint256 t1Min;

        if (params.baseToken == token0Addr) {
            t0Amount = baseAmount;
            t1Amount = farmingAmount;
            t0Min = LiqMath.getMinAmount(t0Amount, params.slippage);
            t1Min = LiqMath.getMinAmount(t1Amount, params.slippage);
        } else {
            t0Amount = farmingAmount;
            t1Amount = baseAmount;
            t0Min = LiqMath.getMinAmount(t0Amount, params.slippage);
            t1Min = LiqMath.getMinAmount(t1Amount, params.slippage);
        }

        INonfungiblePositionManager.MintParams memory mintParams = INonfungiblePositionManager.MintParams(
                token0Addr,
                token1Addr,
                params.fee,
                params.tickLower,
                params.tickUpper,
                t0Amount,
                t1Amount,
                t0Min,
                t1Min,
                address(msg.sender),
                block.timestamp
            );
        return mintParams;
    }
}
