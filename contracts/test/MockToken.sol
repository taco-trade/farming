// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract MockToken is ERC20, Ownable {
    uint8 internal immutable tokenDecimals;

    constructor(
        string memory name,
        string memory symbol,
        uint8 _decimals,
        address owner
    ) ERC20(name, symbol) Ownable(owner) {
        tokenDecimals = _decimals;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }

    function decimals() public view override returns (uint8) {
        return tokenDecimals;
    }
}