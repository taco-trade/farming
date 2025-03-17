// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../UserVault.sol";

contract UserVaultV2 is UserVault {
    function version() external pure returns (uint256) {
        return 2;
    }
}
