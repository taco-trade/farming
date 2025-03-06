// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IManager {
    function poolWhiteList(bytes32) external view returns (bool);

    function userVaults(address) external view returns (address);

    event CreateUserVault(address indexed user, address vault);
    event UpdatePoolWhiteList(
        address token0,
        address token1,
        uint24 fee,
        bool allowed
    );
    event Collect(address indexed user, address token, address recipient);

    function setPoolWhiteList(
        address token0,
        address token1,
        uint24 fee,
        bool allowed
    ) external;

    function work(
        uint256 _positionID,
        address _strategy,
        bytes calldata _data
    ) external;

    function setAgent(address newAgent) external;

    function updateAgentAllowedPool(
        address token0,
        address token1,
        uint24 fee,
        bool allowed
    ) external;

    function collect(address token, address recipient) external;
}
