// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IStrategy} from "../../interfaces/IStrategy.sol";
import {IUserVault} from "../../interfaces/IUserVault.sol";
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
    uint24 fee;
    int24 tickLower; // price ?
    int24 tickUpper; // price ?
    uint256 amount0Min;
    uint256 amount1Min;
    bytes swapPath;
}

contract UniswapV3StrategyAddBaseTokenOnly is
    IStrategy,
    IERC721Receiver,
    OwnableUpgradeable
{
    address public factory;
    address public router;
    address public positionManager;

    event PCSV3AddBaseTokenOnly(
        uint256 indexed tokenID,
        address indexed baseToken,
        address indexed farmingToken,
        uint256 baseTokenAmount,
        uint256 farmingTokenAmount
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
        uint256 /* positionID */,
        bytes calldata data
    ) external override returns (uint8 posType, bytes memory posData) {
        (
            bool _userFund,
            StrategyAddBaseTokenOnlyWithCalculateParam memory params
        ) = abi.decode(
                data,
                (bool, StrategyAddBaseTokenOnlyWithCalculateParam)
            );

        require(
            params.baseToken != address(0),
            "PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate::execute:: invalid baseToken"
        );
        require(
            params.farmingToken != address(0),
            "PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate::execute:: invalid farmingToken"
        );

        if (
            !_validateAgent(
                _caller,
                _userFund,
                params.baseToken,
                params.farmingToken,
                params.fee
            )
        ) {
            revert NotAuthorized();
        }

        if (_userFund) {
            IUserVault(msg.sender).requestFundsFromUser(
                params.baseToken,
                params.totalAmount
            );
        } else {
            IUserVault(msg.sender).requestFunds(
                params.baseToken,
                params.totalAmount
            );
        }

        address poolAddr = IUniswapV3Factory(factory).getPool(
            params.baseToken,
            params.farmingToken,
            params.fee
        );
        // todo: check poolAddr is zero

        // token1/token0
        (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(poolAddr).slot0();
        uint160 sqrtPriceLowerX96 = TickMath.getSqrtRatioAtTick(
            params.tickLower
        );
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtRatioAtTick(
            params.tickUpper
        );

        address token0Addr = IUniswapV3Pool(poolAddr).token0();
        uint256 swapAmount;
        address token1Addr;
        if (params.baseToken == token0Addr) {
            token1Addr = params.farmingToken;
            swapAmount = LiqMath.getToken0SwapAmount(
                sqrtPriceX96,
                sqrtPriceLowerX96,
                sqrtPriceUpperX96,
                params.totalAmount
            );
        } else {
            token1Addr = params.baseToken;
            swapAmount = LiqMath.getToken1SwapAmount(
                sqrtPriceX96,
                sqrtPriceLowerX96,
                sqrtPriceUpperX96,
                params.totalAmount
            );
        }

        SafeERC20.safeIncreaseAllowance(
            IERC20(params.baseToken),
            router,
            swapAmount
        );
        uint256 baseAmount = params.totalAmount - swapAmount;
        uint256 farmingAmount = IV3SwapRouter(router).exactInput(
            IV3SwapRouter.ExactInputParams(
                params.swapPath,
                address(this),
                swapAmount,
                0
            )
        );

        INonfungiblePositionManager.MintParams
            memory mintParams = INonfungiblePositionManager.MintParams(
                token0Addr,
                token1Addr,
                params.fee,
                params.tickLower,
                params.tickUpper,
                params.baseToken == token0Addr ? baseAmount : farmingAmount,
                params.baseToken == token0Addr ? farmingAmount : baseAmount,
                params.amount0Min,
                params.amount1Min,
                address(msg.sender),
                block.timestamp
            );

        SafeERC20.safeIncreaseAllowance(
            IERC20(mintParams.token0),
            positionManager,
            mintParams.amount0Desired
        );
        SafeERC20.safeIncreaseAllowance(
            IERC20(mintParams.token1),
            positionManager,
            mintParams.amount1Desired
        );

        (uint256 tokenID, , , ) = INonfungiblePositionManager(positionManager)
            .mint(mintParams);

        emit PCSV3AddBaseTokenOnly(
            tokenID,
            params.baseToken,
            params.farmingToken,
            baseAmount,
            farmingAmount
        );
        return (
            uint8(PositionType.V3_LP),
            abi.encode(
                V3Position({
                    tokenId: tokenID,
                    token0: params.baseToken,
                    token1: params.farmingToken,
                    fee: params.fee
                })
            )
        );
    }

    function onERC721Received(
        address /* operator */,
        address /* from */,
        uint256 /* tokenId */,
        bytes calldata /* data */
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function _validateAgent(
        address _caller,
        bool _userFund,
        address _token0,
        address _token1,
        uint24 _fee
    ) internal view returns (bool) {
        address _vault = msg.sender;
        if (_caller == IUserVault(_vault).user()) {
            return true;
        }

        if (_caller != IUserVault(_vault).agent()) {
            return false;
        }

        // Agent should not use user fund or pool is not approved
        if (_userFund || !_validatePool(_token0, _token1, _fee)) {
            return false;
        }

        return true;
    }

    function _validatePool(
        address _token0,
        address _token1,
        uint24 _fee
    ) internal view returns (bool) {
        bytes32 _poolKey = keccak256(abi.encodePacked(_token0, _token1, _fee));
        return IUserVault(msg.sender).approvedAgentPools(_poolKey);
    }
}
