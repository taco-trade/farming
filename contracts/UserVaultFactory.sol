// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "./UserVault.sol";

contract UserVaultFactory is UpgradeableBeacon {
    constructor(
        address _implementation,
        address _owner
    ) UpgradeableBeacon(_implementation, _owner) {}

    function createUserVault(address _user, address _manager) external returns (address) {
        return address(new BeaconProxy(address(this), abi.encodeWithSelector(UserVault.initialize.selector, _user, _manager)));
    }
}
