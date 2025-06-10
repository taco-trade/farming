// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./IStrategy.sol";
import "./uniswapV3/periphery/INonfungiblePositionManager.sol";

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
    function approvedAgentPools(bytes32) external view returns (bool);
    function positions(uint256) external view returns (Position memory);

    // State-Changing Functions
    function work(
        address _caller,
        uint256 _positionID,
        address _strategy,
        bytes calldata _data
    ) external;

    function setAgent(address _newAgent) external;

    function setApprovedAgentPools(
        bytes32[] calldata _poolKeys,
        bool _allowed
    ) external;

    /// @notice Collect tokens in this contract
    function collect(address _token, address _recipient) external;

    /// @notice Collect tokens in batch
    function collectInBatch(address[] calldata _tokens, address _recipient) external;

    function requestFundsFromUser(address _token, uint256 _amount) external;

    function requestFunds(address _token, uint256 _amount) external;

    function requestERC721(address _targetedERC721, uint256 _tokenId) external;
}
