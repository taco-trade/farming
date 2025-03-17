// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUserVaultFactory {
    function createUserVault(address _user, address _manager) external returns (address);
}
