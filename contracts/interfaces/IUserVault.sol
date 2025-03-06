// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./IStrategy.sol";
import "./INonfungiblePositionManager.sol";

struct Position {
    // position NFT token ID
    uint8 posType;
    bytes data;
}

interface IUserVault is IERC721Receiver {
    // Events
    event SetAgent(address oldAgent, address newAgent);
    event UpdateAgentPool(bytes32 poolKey, bool allowed);
    event DoWork(address caller, address strategy);

    // View Functions
    function user() external view returns (address);
    function manager() external view returns (address);
    function agent() external view returns (address);
    function agentPoolAllowList(bytes32) external view returns (bool);
    function nftPositionManager() external view returns (INonfungiblePositionManager);
    function positions(uint256) external view returns (Position memory);

    // State-Changing Functions
    function work(
        address _caller,
        uint256 _positionID,
        address _strategy,
        bytes calldata _data
    ) external;

    function setAgent(address caller, address newAgent) external;

    function updateAgentAllowedPool(
        address caller,
        bytes32 poolKey,
        bool allowed
    ) external;
}
