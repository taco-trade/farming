// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IStrategy} from "../../interfaces/IStrategy.sol";
import {IUserVault} from "../../interfaces/IUserVault.sol";
import {ISwapRouter} from "../../interfaces/pancakeswapV3/periphery/ISwapRouter.sol";
import {INonfungiblePositionManager} from "../../interfaces/pancakeswapV3/periphery/INonfungiblePositionManager.sol";

struct StrategyAddBaseTokenOnlyParam {
    address baseToken;
    address farmingToken;
    uint256 totalAmount;
    uint256 swapAmount;
    uint24 fee;
    int24 tickLower;
    int24 tickUpper;
    uint256 amount0Min;
    uint256 amount1Min;
    bytes swapPath;
}

contract PancakeswapV3StrategyAddBaseTokenOnly is
    IStrategy,
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
        (bool _userFund, StrategyAddBaseTokenOnlyParam memory params) = abi
            .decode(data, (bool, StrategyAddBaseTokenOnlyParam));

        require(
            params.baseToken != address(0),
            "PancakeswapV3StrategyAddBaseTokenOnly::execute:: invalid baseToken"
        );
        require(
            params.farmingToken != address(0),
            "PancakeswapV3StrategyAddBaseTokenOnly::execute:: invalid farmingToken"
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

        // uint256 balance = IERC20(params.baseToken).balanceOf(msg.sender);
        // require(
        //     balance >= params.totalAmount,
        //     "PancakeswapV3StrategyAddBaseTokenOnly::execute:: insufficient balance"
        // );

        // expect price range [P0, P1], current price P in range [P0, P1]
        // if amount of token0 is  x, amount of token1 is  y
        // then L = x/ (1/sqrt{P} - 1/sqrt{P1}) = y/(sqrt{P} - sqrt{P0})
        // now we know input = x+y, and P0, P1, P, how to get x, y

        // sqrt{P0} = (sqrt{1.0001})^lowerIndex
        // sqrt{P1} = (sqrt{1.0001})^upperIndex
        // Px = 1/sqrt{P} - 1/sqrt{P1}
        // Py = sqrt{P} - sqrt{P0}
        // L = input / (Px + Py)
        // x = L * Px
        // y = input - x = L * Py

        SafeERC20.safeIncreaseAllowance(
            IERC20(params.baseToken),
            router,
            params.swapAmount
        );

        uint256 baseAmount = params.totalAmount - params.swapAmount;
        uint256 farmingAmount = ISwapRouter(router).exactInput(
            ISwapRouter.ExactInputParams(
                params.swapPath,
                address(this),
                block.timestamp,
                params.swapAmount,
                0
            )
        );

        INonfungiblePositionManager.MintParams
            memory mintParams = INonfungiblePositionManager.MintParams(
                params.baseToken,
                params.farmingToken,
                params.fee,
                params.tickLower,
                params.tickUpper,
                baseAmount,
                farmingAmount,
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
