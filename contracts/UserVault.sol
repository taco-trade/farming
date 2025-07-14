// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "./interfaces/IStrategy.sol";
import "./interfaces/uniswapV3/periphery/INonfungiblePositionManager.sol";
import {Position, IUserVault} from "./interfaces/IUserVault.sol";

contract UserVault is IUserVault, Initializable {
    address public user;
    address public manager;
    address private _agent;

    mapping(bytes32 => bool) public approvedAgentPools;
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

    // Custom errors
    error OnlyManager();
    error NotWithinExecutionScope();
    error NotFromStrategy();
    error InExecLock();
    error NotUser();
    error NotInExec();
    error BadPositionID();

    modifier onlyManager() {
        if (msg.sender != manager && msg.sender != user) revert OnlyManager();
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

    function initialize(address _user, address _manager) external initializer {
        user = _user;
        manager = _manager;
        nextPositionId = 1;

        _IN_EXEC_LOCK = _NOT_ENTERED;
        POSITION_ID = _NO_ID;
        STRATEGY = _NO_ADDRESS;
    }

    /// @notice agent address is publicly readable
    function agent() external view returns (address) {
        return _agent;
    }

    /// @notice Returns the position data for a given position ID
    function positions(
        uint256 _positionId
    ) external view returns (Position memory) {
        return _positions[_positionId];
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
        Position storage _pos;
        if (_positionID == 0) {
            _positionID = nextPositionId;
            nextPositionId += 1;
            _pos = _positions[_positionID];
        } else {
            _pos = _positions[_positionID];
            if (_positionID >= nextPositionId) revert BadPositionID();
        }

        // Set the execution scope
        STRATEGY = _strategy;
        POSITION_ID = _positionID;

        // If the user calls this function directly,
        // we need to set the caller to the user manually.
        if (msg.sender != manager) {
            _caller = msg.sender;
        }

        // Execute the strategy
        (uint8 posType, bytes memory posData) = IStrategy(_strategy).execute(
            _caller,
            _positionID,
            _data
        );
        _pos.posType = posType;
        _pos.data = posData;

        // Reset the execution scope
        POSITION_ID = _NO_ID;
        STRATEGY = _NO_ADDRESS;

        emit DoWork(_caller, _strategy);
    }

    /// @notice Manager.setAgent(...) called
    function setAgent(address _newAgent) external onlyManager {
        address _oldAgent = _agent;
        _agent = _newAgent;
        emit SetAgent(_oldAgent, _newAgent);
    }

    /// @notice Manager.setApprovedAgentPools(...) called
    function setApprovedAgentPools(
        bytes32[] calldata _poolKeys,
        bool _allowed
    ) external onlyManager {
        for (uint256 i = 0; i < _poolKeys.length; i++) {
            approvedAgentPools[_poolKeys[i]] = _allowed;
            emit UpdateAgentPool(_poolKeys[i], _allowed);
        }
    }

    /// @notice Collect tokens in this contract
    function collect(address _token, address _recipient) external onlyManager {
        SafeERC20.safeTransfer(
            IERC20(_token),
            _recipient,
            IERC20(_token).balanceOf(address(this))
        );
    }

    function collectInBatch(address[] calldata _tokens, address _recipient) external onlyManager {
        for (uint256 i = 0; i < _tokens.length; i++) {
            SafeERC20.safeTransfer(
                IERC20(_tokens[i]),
                _recipient,
                IERC20(_tokens[i]).balanceOf(address(this))
            );
        }
    }

    // ---------------- only strategy in exec scope can call functions ----------------- //

    function requestFunds(
        address targetedToken,
        uint256 amount
    ) external inExec {
        SafeERC20.safeTransfer(
            IERC20(targetedToken),
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

    function requestERC721(
        address targetedERC721,
        uint256 tokenId
    ) external inExec {
        IERC721(targetedERC721).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId
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
