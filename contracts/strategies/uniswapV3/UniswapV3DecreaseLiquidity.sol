// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {INonfungiblePositionManager} from "../../interfaces/uniswapV3/periphery/INonfungiblePositionManager.sol";
import {IStrategy} from "../../interfaces/IStrategy.sol";
import {IUserVault, Position} from "../../interfaces/IUserVault.sol";

enum Receipient {
    User,
    Vault
}

struct StrategyParams {
    uint128 liquidity;
    uint256 amount0Min;
    uint256 amount1Min;
    Receipient recipient;
}

contract UniswapV3DecreaseLiquidity is IStrategy, OwnableUpgradeable {
    address public positionManager;

    function initialize(address _positionManager) external initializer {
        OwnableUpgradeable.__Ownable_init(msg.sender);
        positionManager = _positionManager;
    }

    function execute(
        address /* _caller */,
        uint256 _positionID,
        bytes calldata _data
    ) external override returns (uint8 posType, bytes memory posData) {
        // Decode params
        StrategyParams memory _params = abi.decode(_data, (StrategyParams));
        Position memory _position = IUserVault(msg.sender).positions(
            _positionID
        );
        V3Position memory _v3Position = abi.decode(
            _position.data,
            (V3Position)
        );

        address recipient = _params.recipient == Receipient.Vault
            ? msg.sender
            : IUserVault(msg.sender).user();

        // Handle liquidity decrease and token collection
        _decreaseLiquidityAndCollect(_v3Position.tokenId, _params, recipient);

        // Handle token transfers
        _handleTokenTransfers(recipient, _v3Position.token0, _v3Position.token1);

        return (
            uint8(PositionType.V3_LP),
            abi.encode(
                V3Position({
                    tokenId: _v3Position.tokenId,
                    token0: _v3Position.token0,
                    token1: _v3Position.token1
                })
            )
        );
    }

    function _decreaseLiquidityAndCollect(
        uint256 _tokenId,
        StrategyParams memory params,
        address recipient
    ) internal {
        // Get the position NFT
        IUserVault(msg.sender).requestERC721(positionManager, _tokenId);

        // Decrease liquidity
        INonfungiblePositionManager(positionManager).decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: _tokenId,
                liquidity: params.liquidity,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min,
                deadline: block.timestamp
            })
        );

        // Collect tokens
        INonfungiblePositionManager(positionManager).collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: _tokenId,
                recipient: recipient,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        // Transfer the NFT back to the UserVault
        IERC721(positionManager).safeTransferFrom(address(this), msg.sender, _tokenId);
    }

    function _handleTokenTransfers(
        address recipient,
        address token0,
        address token1
    ) internal {
        SafeERC20.safeTransfer(
            IERC20(token0),
            recipient,
            IERC20(token0).balanceOf(address(this))
        );
        SafeERC20.safeTransfer(
            IERC20(token1),
            recipient,
            IERC20(token1).balanceOf(address(this))
        );
    }

    function onERC721Received(
        address /* operator */,
        address /* from */,
        uint256 /* tokenId */,
        bytes calldata /* data */
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
    
}
