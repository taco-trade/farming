// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IManager {
    event CreateUserVault(address indexed user, address vault);
    event UpdateApprovedPool(bytes32 pool, bool allowed);
    event UpdateApprovedStrategy(address strategy, bool allowed);
    event Collect(address indexed user, address token, address recipient);

    function approvedPools(bytes32) external view returns (bool);

    function approvedStrategies(address) external view returns (bool);

    function userVaults(address) external view returns (address);

    function createUserVault(address _agent) external;

    function setApprovedPools(bytes32[] calldata pools, bool allowed) external;

    function setApprovedAgentPools(
        bytes32[] calldata _poolKeys,
        bool _allowed
    ) external;

    function setApprovedStrategies(address[] calldata strategies, bool allowed) external;

    function work(
        address _vaultAddr,
        uint256 _positionID,
        address _strategy,
        bytes calldata _data
    ) external;

    function setAgent(address newAgent) external;

    function collect(address token, address recipient) external;

    function collectInBatch(address[] calldata tokens, address recipient) external;
}
