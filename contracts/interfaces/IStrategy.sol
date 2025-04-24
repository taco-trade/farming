// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStrategy {
    enum PositionType {
        V3_LP
    }

    struct V3Position {
        uint256 tokenId;
        address token0;
        address token1;
        uint24 fee;
    }

    error NotAuthorized();

    /**
     * @notice Called by UserVault in managerWork(...) to delegate actual operation logic to strategy
     * @param caller   The caller address, user or agent.
     * @param data   Arbitrary custom operation parameters packed by frontend/caller
     */
    function execute(
        address caller,
        uint256 positionId,
        bytes calldata data
    ) external returns (uint8 posType, bytes memory posData);
}