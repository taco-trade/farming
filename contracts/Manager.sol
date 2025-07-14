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
    function createUserVault(address _agent) external {
        if (userVaults[msg.sender] != address(0)) revert VaultAlreadyExists();
        address _vault = _createUserVault(msg.sender);
        UserVault(_vault).setAgent(_agent);
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
        address _vaultAddr,
        uint256 _positionID,
        address _strategy,
        bytes calldata _data
    ) external nonReentrant {
        if (_vaultAddr == address(0)) {
            revert NoVault();
        }

        // 1. Check if the strategy is whitelisted
        if (!approvedStrategies[_strategy]) revert StrategyNotWhitelisted();

        // 2. Check if the caller is the user themselves or the vault's agent
        UserVault _v = UserVault(_vaultAddr);
        address _currentAgent = _v.agent(); // the agent address recorded in the vault
        if (msg.sender != _v.user() && msg.sender != _currentAgent)
            revert NotUserNorAgent();

        // 3. Call the vault's work to perform the actual operation
        UserVault(_vaultAddr).work(msg.sender, _positionID, _strategy, _data);
    }

    /// @notice Allows a user to set their agent address in the manager
    /// @param _newAgent New agent address
    function setAgent(address _newAgent) external {
        address vaultAddr = userVaults[msg.sender];
        if (vaultAddr == address(0)) revert NoVault();
        UserVault(vaultAddr).setAgent(_newAgent);
    }

    /// @notice Allows a user to update their agent's allowed pools whitelist (specific to this user only)
    /// @param _poolKeys The pool keys to update, must be in the global whitelist.
    ///     Key is the result of the keccak256(abi.encodePacked(address0, address1, fee)) function.
    /// @param _allowed Whether the pools are allowed
    function setApprovedAgentPools(
        bytes32[] calldata _poolKeys,
        bool _allowed
    ) external {
        address vaultAddr = userVaults[msg.sender];
        if (vaultAddr == address(0)) revert NoVault();

        for (uint256 i = 0; i < _poolKeys.length; i++) {
            bytes32 key = _poolKeys[i];
            if (!approvedPools[key]) revert PoolNotInGlobalWhitelist();
        }

        UserVault(vaultAddr).setApprovedAgentPools(_poolKeys, _allowed);
    }

    /// @notice Collect tokens in the user's vault
    function collect(address token, address recipient) external nonReentrant {
        address vaultAddr = userVaults[msg.sender];
        if (vaultAddr == address(0)) revert NoVault();
        UserVault(vaultAddr).collect(token, recipient);
        emit Collect(msg.sender, token, recipient);
    }

    /// @notice Collect tokens in batch
    function collectInBatch(address[] calldata tokens, address recipient) external nonReentrant {
        address vaultAddr = userVaults[msg.sender];
        if (vaultAddr == address(0)) revert NoVault();
        UserVault(vaultAddr).collectInBatch(tokens, recipient);
    }

    /// @dev Internal function to create a UserVault for a user
    function _createUserVault(address _user) internal returns (address) {
        address _vault = IUserVaultFactory(userVaultFactory).createUserVault(_user, address(this));
        userVaults[_user] = address(_vault);
        emit CreateUserVault(_user, address(_vault));
        return address(_vault);
    }
}
