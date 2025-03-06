// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IStrategy.sol";
import "./interfaces/INonfungiblePositionManager.sol";
import {Position, IUserVault} from "./interfaces/IUserVault.sol";

contract UserVault is IUserVault {
    // Custom errors
    error OnlyManager();
    error NotWithinExecutionScope();
    error NotFromStrategy();
    error InExecLock();
    error NotUser();
    error NotInExec();
    error BadPositionID();

    address public immutable user;
    address public immutable manager;

    address private _agent;

    INonfungiblePositionManager public nftPositionManager;
    mapping(bytes32 => bool) public agentPoolAllowList;
    mapping(uint256 => Position) private _positions;
    uint256 public nextPositionId;

    /// @dev Flags for manage execution scope
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private constant _NO_ID = type(uint256).max;
    address private constant _NO_ADDRESS = address(1);

    /// @dev Temporay variables to manage execution scope
    uint256 public _IN_EXEC_LOCK;
    uint256 public POSITION_ID;
    address public STRATEGY;

    modifier onlyManager() {
        if (msg.sender != manager) revert OnlyManager();
        _;
    }

    modifier inExec() {
        if (POSITION_ID == _NO_ID) revert NotWithinExecutionScope();
        if (STRATEGY != msg.sender) revert NotFromStrategy();
        if (_IN_EXEC_LOCK != _NOT_ENTERED) revert InExecLock();
        _IN_EXEC_LOCK = _ENTERED;
        _;
        _IN_EXEC_LOCK = _NOT_ENTERED;
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

    /// @notice Returns the position data for a given position ID
    function positions(uint256 positionId) external view returns (Position memory) {
        return _positions[positionId];
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
        Position storage _pos;
        if (_positionID == 0) {
            _positionID = nextPositionId;
            nextPositionId += 1;
            _pos = _positions[_positionID];
        } else {
            _pos = _positions[_positionID];
            if (_positionID < nextPositionId) revert BadPositionID();
        }
        // Set the execution scope
        STRATEGY = _strategy;
        POSITION_ID = _positionID;

        // Execute the strategy
        (uint8 posType, bytes memory posData) = IStrategy(_strategy).execute(user, _data);
        _pos.posType = posType;
        _pos.data = posData;

        // Reset the execution scope
        POSITION_ID = _NO_ID;
        STRATEGY = _NO_ADDRESS;

        emit DoWork(_caller, _strategy);
    }

    /// @notice Manager.setAgent(...) called
    function setAgent(address caller, address newAgent) external onlyManager {
        if (caller != user) revert NotUser();
        address old = _agent;
        _agent = newAgent;
        emit SetAgent(old, newAgent);
    }

    /// @notice Manager.updateAgentAllowedPool(...) called
    function updateAgentAllowedPool(
        address caller,
        bytes32 poolKey,
        bool allowed
    ) external onlyManager {
        if (caller != user) revert NotUser();
        agentPoolAllowList[poolKey] = allowed;
        emit UpdateAgentPool(poolKey, allowed);
    }

    /// @notice Collect tokens in this contract
    function collect(address token, address recipient) external onlyManager {
        SafeERC20.safeTransfer(IERC20(token), recipient, IERC20(token).balanceOf(address(this)));
    }

    // ---------------- only strategy in exec scope can call functions ----------------- //

    function requestFunds(
        address targetedToken,
        uint256 amount
    ) external inExec {
        SafeERC20.safeTransferFrom(
            IERC20(targetedToken),
            address(this),
            msg.sender,
            amount
        );
    }

    function requestFundsFromUser(
        address targetedToken,
        uint256 amount
    ) external inExec {
        SafeERC20.safeTransferFrom(
            IERC20(targetedToken),
            user,
            msg.sender,
            amount
        );
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
