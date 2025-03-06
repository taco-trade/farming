// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStrategy {
    enum PositionType {
        V3_LP
    }

    /**
     * @notice Called by UserVault in managerWork(...) to delegate actual operation logic to strategy
     * @param user   The user address corresponding to the UserVault
     * @param data   Arbitrary custom operation parameters packed by frontend/caller
     */
    function execute(
        address user,
        bytes calldata data
    ) external returns (uint8 posType, bytes memory posData);
}