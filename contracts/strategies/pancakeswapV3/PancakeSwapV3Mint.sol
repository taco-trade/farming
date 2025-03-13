// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {INonfungiblePositionManager} from "../../interfaces/pancakeswapV3/periphery/INonfungiblePositionManager.sol";
import {IStrategy} from "../../interfaces/IStrategy.sol";
import {IUserVault} from "../../interfaces/IUserVault.sol";

contract PancakeSwapV3Mint is IStrategy, IERC721Receiver, OwnableUpgradeable {
    address public positionManager;

    function initialize(
        address _positionManager
    ) external initializer {
        OwnableUpgradeable.__Ownable_init(msg.sender);
        positionManager = _positionManager;
    }

    function execute(
        address /* _caller */,
        uint256 /* _positionID */,
        bytes calldata _data
    ) external override returns (uint8 posType, bytes memory posData) {
        INonfungiblePositionManager.MintParams memory params = abi.decode(
            _data,
            (INonfungiblePositionManager.MintParams)
        );

        SafeERC20.safeIncreaseAllowance(
            IERC20(params.token0),
            positionManager,
            params.amount0Desired
        );
        SafeERC20.safeIncreaseAllowance(
            IERC20(params.token1),
            positionManager,
            params.amount1Desired
        );

        IUserVault(msg.sender).requestFundsFromUser(
            params.token0,
            params.amount0Desired
        );
        IUserVault(msg.sender).requestFundsFromUser(
            params.token1,
            params.amount1Desired
        );

        params.recipient = msg.sender;
        params.deadline = block.timestamp;

        (uint256 tokenID, , , ) = INonfungiblePositionManager(positionManager)
            .mint(params);

        return (
            uint8(PositionType.V3_LP),
            abi.encode(
                V3Position({
                    tokenId: tokenID,
                    token0: params.token0,
                    token1: params.token1
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
}
