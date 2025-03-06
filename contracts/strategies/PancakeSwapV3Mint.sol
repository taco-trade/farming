// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {INonfungiblePositionManager, MintParams} from "../interfaces/INonfungiblePositionManager.sol";
import {IStrategy} from "../interfaces/IStrategy.sol";

contract PancakeSwapV3Mint is IStrategy, IERC721Receiver {
    address public factory;
    address public router;
    address public positionManager;

    constructor(address _factory, address _router, address _positionManager) {
        factory = _factory;
        router = _router;
        positionManager = _positionManager;
    }

    function execute(
        address /* _user */,
        bytes calldata _data
    ) external override returns (uint8 posType, bytes memory posData) {
        MintParams memory params = abi.decode(_data, (MintParams));

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

        params.recipient = msg.sender;
        params.deadline = block.timestamp;

        (uint256 tokenID, , , ) = INonfungiblePositionManager(positionManager)
            .mint(params);

        return (uint8(PositionType.V3_LP), abi.encode(tokenID));
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
