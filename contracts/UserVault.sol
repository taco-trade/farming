// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./interfaces/IStrategy.sol";
import "./interfaces/INonfungiblePositionManager.sol";
import "./interfaces/IUserVault.sol";


contract UserVault is IUserVault {
    address public immutable user;
    address public immutable manager;

    address private _agent;

    mapping(bytes32 => bool) public agentPoolAllowList;
    INonfungiblePositionManager public nftPositionManager;
    mapping(uint256 => uint256) public positionTokenId;
    uint256 public nextPositionId;

    modifier onlyManager() {
        require(msg.sender == manager, "Only manager");
        _;
    }

    constructor(address _user, address _manager, address _nftPositionManager) {
        user = _user;
        manager = _manager;
        nftPositionManager = INonfungiblePositionManager(_nftPositionManager);
        nextPositionId = 1;
    }

    /// @notice agent address is publicly readable
    function agent() external view returns (address) {
        return _agent;
    }

    // ---------------- only manager can call functions ----------------- //

    /// @param _positionID   position NFT token ID
    /// @param _strategy     strategy address
    /// @param _data         custom data for strategy
    function work(
        address _caller,
        uint256 _positionID,
        address _strategy,
        bytes calldata _data
    ) external onlyManager {
        // call strategy
        // note: strategy can call internal functions of this contract or interact with swap directly
        IStrategy(_strategy).execute(
            user,
            _data
        );

        emit DoWork(_caller, _strategy);
    }

    /**
     * @notice Manager.setAgent(...) called
     */
    function setAgent(address caller, address newAgent) external onlyManager {
        require(caller == user, "Not user");
        address old = _agent;
        _agent = newAgent;
        emit SetAgent(old, newAgent);
    }

    /**
     * @notice Manager.updateAgentAllowedPool(...) called
     */
    function updateAgentAllowedPool(
        address caller,
        bytes32 poolKey,
        bool allowed
    ) external onlyManager {
        require(caller == user, "Not user");
        agentPoolAllowList[poolKey] = allowed;
        emit UpdateAgentPool(poolKey, allowed);
    }

    // ---------------- IERC721Receiver ------------------ //

    function onERC721Received(
        address /* operator */,
        address /* from */,
        uint256 /* tokenId */,
        bytes calldata /* data */
    ) external pure override returns (bytes4) {
        // can verify specific NFT here
        return IERC721Receiver.onERC721Received.selector;
    }
}