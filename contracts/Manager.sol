// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IManager.sol";
import "./UserVault.sol";

contract Manager is IManager, Ownable {
    error PoolNotWhitelisted();
    error NotUserNorAgent();
    error NoVault();
    error PoolNotInGlobalWhitelist();

    /// state variables
    address public immutable nftPositionManager;

    /// @notice keccak256(token0, token1, fee) -> bool, indicates whether the pool is in the global whitelist
    mapping(bytes32 => bool) public poolWhiteList;

    /// @notice user address => user's dedicated UserVault
    mapping(address => address) public userVaults;

    constructor(address _owner, address _nftPositionManager) Ownable(_owner) {
        nftPositionManager = _nftPositionManager;
    }

    /// @notice Admin function to set pool whitelist for token pairs
    /// @param token0 The first token of the pool
    /// @param token1 The second token of the pool
    /// @param fee The fee of the pool
    /// @param allowed Whether the pool is in the whitelist
    function setPoolWhiteList(
        address token0,
        address token1,
        uint24 fee,
        bool allowed
    ) external onlyOwner {
        bytes32 key = _getPoolKey(token0, token1, fee);
        poolWhiteList[key] = allowed;
        emit UpdatePoolWhiteList(token0, token1, fee, allowed);
    }

    /// @notice Executes unified operations on a pool position for a user;
    /// all logic is encapsulated in the `strategy` contract and `data`
    /// @dev `msg.sender` can be either the user themselves or their agent
    /// @param _positionID The ID of the position to work on
    /// @param _strategy Strategy contract address
    /// @param _data     Custom data passed to the strategy
    function work(
        uint256 _positionID,
        address _strategy,
        bytes calldata _data
    ) external {
        address vaultAddr = userVaults[msg.sender];
        if (vaultAddr == address(0)) {
            vaultAddr = _createUserVault(msg.sender);
        }

        // 1. Check if the caller is the user themselves or the vault's agent
        UserVault v = UserVault(vaultAddr);
        address currentAgent = v.agent(); // the agent address recorded in the vault
        if (msg.sender != msg.sender && msg.sender != currentAgent) revert NotUserNorAgent();

        // 2. Call the vault's managerWork to perform the actual operation
        UserVault(vaultAddr).work(
            msg.sender,
            _positionID,
            _strategy,
            _data
        );
    }

    /**
     * @notice Allows a user to set their agent address in the manager
     * @param newAgent New agent address
     */
    function setAgent(address newAgent) external {
        address vaultAddr = userVaults[msg.sender];
        if (vaultAddr == address(0)) revert NoVault();
        UserVault(vaultAddr).setAgent(msg.sender, newAgent);
    }

    /// @notice Allows a user to update their agent's allowed pools whitelist (specific to this user only)
    function updateAgentAllowedPool(
        address token0,
        address token1,
        uint24 fee,
        bool allowed
    ) external {
        address vaultAddr = userVaults[msg.sender];
        if (vaultAddr == address(0)) revert NoVault();
        bytes32 key = _getPoolKey(token0, token1, fee);
        if (!poolWhiteList[key]) revert PoolNotInGlobalWhitelist();

        UserVault(vaultAddr).updateAgentAllowedPool(msg.sender, key, allowed);
    }

    /// @dev Internal function to create a UserVault for a user
    function _createUserVault(address _user) internal returns (address) {
        UserVault vault = new UserVault(_user, address(this), nftPositionManager);
        userVaults[_user] = address(vault);
        emit CreateUserVault(_user, address(vault));
        return address(vault);
    }

    /// @dev Converts (token0, token1, fee) into a key
    function _getPoolKey(
        address token0,
        address token1,
        uint24 fee
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(token0, token1, fee));
    }
}
