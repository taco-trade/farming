// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./interfaces/IManager.sol";
import "./interfaces/IUserVaultFactory.sol";
import {UserVault} from "./UserVault.sol";

contract Manager is IManager, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    /// state variables
    address public userVaultFactory;

    /// @notice keccak256(token0, token1, fee) -> bool, indicates whether the pool is in the global whitelist
    mapping(bytes32 => bool) public approvedPools;

    /// @notice user address => user's dedicated UserVault
    mapping(address => address) public userVaults;

    /// @notice strategy address => allowed
    mapping(address => bool) public approvedStrategies;

    /// @notice errors
    error PoolNotWhitelisted();
    error NotUserNorAgent();
    error NoVault();
    error PoolNotInGlobalWhitelist();
    error VaultAlreadyExists();
    error StrategyNotWhitelisted();

    function initialize(
        address _owner,
        address _userVaultFactory
    ) external initializer {
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        OwnableUpgradeable.__Ownable_init(_owner);
        userVaultFactory = _userVaultFactory;
    }

    /// @notice Admin function to set pool whitelist for token pairs
    function setApprovedPools(bytes32[] calldata pools, bool allowed) external onlyOwner {
        for (uint256 i = 0; i < pools.length; i++) {
            approvedPools[pools[i]] = allowed;
            emit UpdateApprovedPool(pools[i], allowed);
        }
    }

    /// @notice Creates a new UserVault for a user
    function createUserVault() external {
        if (userVaults[msg.sender] != address(0)) revert VaultAlreadyExists();
        _createUserVault(msg.sender);
    }

    /// @notice Admin function to set strategy whitelist
    function setApprovedStrategies(address[] calldata strategies, bool allowed) external onlyOwner {
        for (uint256 i = 0; i < strategies.length; i++) {
            approvedStrategies[strategies[i]] = allowed;
            emit UpdateApprovedStrategy(strategies[i], allowed);
        }
    }

    /// @notice Executes unified operations on a pool position for a user;
    /// all logic is encapsulated in the `strategy` contract and `data`
    /// @dev `msg.sender` can be either the user themselves or the vault's agent
    /// @param _positionID The ID of the position to work on
    /// @param _strategy Strategy contract address
    /// @param _data     Custom data passed to the strategy
    function work(
        uint256 _positionID,
        address _strategy,
        bytes calldata _data
    ) external nonReentrant {
        address vaultAddr = userVaults[msg.sender];
        if (vaultAddr == address(0)) {
            revert NoVault();
        }

        // 1. Check if the strategy is whitelisted
        if (!approvedStrategies[_strategy]) revert StrategyNotWhitelisted();

        // 2. Check if the caller is the user themselves or the vault's agent
        UserVault v = UserVault(vaultAddr);
        address currentAgent = v.agent(); // the agent address recorded in the vault
        if (msg.sender != msg.sender && msg.sender != currentAgent)
            revert NotUserNorAgent();

        // 3. Call the vault's managerWork to perform the actual operation
        UserVault(vaultAddr).work(msg.sender, _positionID, _strategy, _data);
    }

    /// @notice Allows a user to set their agent address in the manager
    /// @param newAgent New agent address
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
        if (!approvedPools[key]) revert PoolNotInGlobalWhitelist();

        UserVault(vaultAddr).updateAgentAllowedPool(msg.sender, key, allowed);
    }

    /// @notice Collect tokens in this contract
    function collect(address token, address recipient) external nonReentrant {
        address vaultAddr = userVaults[msg.sender];
        if (vaultAddr == address(0)) revert NoVault();
        UserVault(vaultAddr).collect(token, recipient);
        emit Collect(msg.sender, token, recipient);
    }

    /// @dev Internal function to create a UserVault for a user
    function _createUserVault(address _user) internal returns (address) {
        address _vault = IUserVaultFactory(userVaultFactory).createUserVault(_user, address(this));
        userVaults[_user] = address(_vault);
        emit CreateUserVault(_user, address(_vault));
        return address(_vault);
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
