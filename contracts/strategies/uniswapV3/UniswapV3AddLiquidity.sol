// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {IV3SwapRouter} from "../../interfaces/uniswapV3/periphery/IV3SwapRouter.sol";
import {INonfungiblePositionManager} from "../../interfaces/uniswapV3/periphery/INonfungiblePositionManager.sol";
import {IStrategy} from "../../interfaces/IStrategy.sol";
import {IUserVault, Position} from "../../interfaces/IUserVault.sol";
import "../../libraries/LiqMath.sol";
import "../../libraries/TickMath.sol";
import "../../interfaces/uniswapV3/core/IUniswapV3Factory.sol";
import "../../interfaces/uniswapV3/core/IUniswapV3Pool.sol";

struct StrategyParams {
    uint256 amount0Desired;
    uint256 amount1Desired;
    uint256 amount0Min;
    uint256 amount1Min;
    bool userFund;
    bytes token0SwapPath;
    bytes token1SwapPath;
}

contract UniswapV3AddLiquidity is
    IStrategy,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    address public positionManager;
    address public factory;
    address public router;

    error PositionNotExists();

    event AddLiquidity(
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
        address _positionManager,
        address _factory,
        address _router
    ) external initializer {
        OwnableUpgradeable.__Ownable_init(msg.sender);
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        positionManager = _positionManager;
        factory = _factory;
        router = _router;
    }

    function execute(
        address _caller,
        uint256 _positionID,
        bytes calldata _data
    )
        external
        override
        nonReentrant
        returns (uint8 posType, bytes memory posData)
    {
        // Validate position and params
        Position memory _position = IUserVault(msg.sender).positions(
            _positionID
        );
        if (_position.data.length == 0) revert PositionNotExists();
        V3Position memory _v3Position = abi.decode(
            _position.data,
            (V3Position)
        );
        StrategyParams memory _params = abi.decode(_data, (StrategyParams));

        _validateParams(_caller, _params.userFund);
        _requestFunds(
            _v3Position.token0,
            _params.amount0Desired,
            _v3Position.token1,
            _params.amount1Desired,
            _params.userFund
        );

        (uint256 _t0Amount, uint256 _t1Amount) = _swapIfNeeded(
            _v3Position.token0,
            _v3Position.token1,
            _params.amount0Desired,
            _params.amount1Desired,
            _v3Position.fee,
            _v3Position.tokenId,
            _params.token0SwapPath,
            _params.token1SwapPath
        );

        IERC20(_v3Position.token0).approve(positionManager, _t0Amount);
        IERC20(_v3Position.token1).approve(positionManager, _t1Amount);

        INonfungiblePositionManager.IncreaseLiquidityParams
            memory _decParams = INonfungiblePositionManager
                .IncreaseLiquidityParams({
                    tokenId: _v3Position.tokenId,
                    amount0Desired: _t0Amount,
                    amount1Desired: _t1Amount,
                    amount0Min: _params.amount0Min,
                    amount1Min: _params.amount1Min,
                    deadline: block.timestamp
                });
        (uint128 _liquidity, uint256 _amount0, uint256 _amount1) = INonfungiblePositionManager(positionManager)
            .increaseLiquidity(_decParams);

        _refundTokens(_v3Position.token0, _v3Position.token1, _params.userFund);

        emit AddLiquidity(msg.sender, _positionID, _v3Position.tokenId, _v3Position.token0, _v3Position.token1, _liquidity, _amount0, _amount1);

        _position.data = abi.encode(_v3Position);
        return (uint8(PositionType.V3_LP), _position.data);
    }

    function _validateParams(address _caller, bool _userFund) internal view {
        address _user = IUserVault(msg.sender).user();
        if (_caller == _user) return;
        address _agent = IUserVault(msg.sender).agent();
        if (_caller != _agent) revert NotAuthorized();
        if (_caller == _agent && _userFund) revert NotAuthorized();
    }

    function _requestFunds(
        address _token0,
        uint256 _amount0,
        address _token1,
        uint256 _amount1,
        bool _userFund
    ) internal {
        if (_userFund) {
            IUserVault(msg.sender).requestFundsFromUser(_token0, _amount0);
            IUserVault(msg.sender).requestFundsFromUser(_token1, _amount1);
        } else {
            IUserVault(msg.sender).requestFunds(_token0, _amount0);
            IUserVault(msg.sender).requestFunds(_token1, _amount1);
        }
    }

    function _swapIfNeeded(
        address _token0,
        address _token1,
        uint256 _amount0,
        uint256 _amount1,
        uint24 _fee,
        uint256 _tokenID,
        bytes memory _token0SwapPath,
        bytes memory _token1SwapPath
    ) internal returns (uint256 _t0Amount, uint256 _t1Amount) {
        (bool _isToken0, uint256 _swapAmount) = _getSwapAmount(
            _token0,
            _token1,
            _amount0,
            _amount1,
            _fee,
            _tokenID
        );
        if (_swapAmount > 0) {
            if (_isToken0) {
                _swap(_token0, _swapAmount, _token0SwapPath);
            } else {
                _swap(_token1, _swapAmount, _token1SwapPath);
            }
        }
        _t0Amount = IERC20(_token0).balanceOf(address(this));
        _t1Amount = IERC20(_token1).balanceOf(address(this));
    }

    function _getSwapAmount(
        address _token0,
        address _token1,
        uint256 _amount0,
        uint256 _amount1,
        uint24 _fee,
        uint256 _tokenID
    ) internal view returns (bool _isToken0, uint256 _swapAmount) {
        // Get pool info
        address poolAddr = IUniswapV3Factory(factory).getPool(
            _token0,
            _token1,
            _fee
        );
        // Get tick range
        (int24 _tickLower, int24 _tickUpper) = _getTickRange(_tokenID);
        // Get current price and tick bounds
        (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(poolAddr).slot0();
        uint160 sqrtPriceLowerX96 = TickMath.getSqrtRatioAtTick(_tickLower);
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtRatioAtTick(_tickUpper);

        // Calculate optimal amounts based on price range
        (_isToken0, _swapAmount) = LiqMath.getSwapAmount(
            sqrtPriceX96,
            sqrtPriceLowerX96,
            sqrtPriceUpperX96,
            _amount0,
            _amount1,
            10000 // 1% tolerance
        );
    }

    function _getTickRange(
        uint256 _tokenID
    ) internal view returns (int24 _tickLower, int24 _tickUpper) {
        (,,,,,_tickLower,_tickUpper,,,,,) = INonfungiblePositionManager(positionManager).positions(_tokenID);
    }

    function _swap(
        address _token,
        uint256 _amount,
        bytes memory _swapPath
    ) internal {
        SafeERC20.safeIncreaseAllowance(IERC20(_token), router, _amount);
        IV3SwapRouter(router).exactInput(
            IV3SwapRouter.ExactInputParams(_swapPath, address(this), _amount, 0)
        );
    }

    function _refundTokens(
        address _token0,
        address _token1,
        bool _userFund
    ) internal {
        address refundAddr = _userFund
            ? IUserVault(msg.sender).user()
            : msg.sender;
        SafeERC20.safeTransfer(
            IERC20(_token0),
            refundAddr,
            IERC20(_token0).balanceOf(address(this))
        );
        SafeERC20.safeTransfer(
            IERC20(_token1),
            refundAddr,
            IERC20(_token1).balanceOf(address(this))
        );
    }
}
