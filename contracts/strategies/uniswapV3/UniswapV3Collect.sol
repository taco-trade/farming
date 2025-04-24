// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {INonfungiblePositionManager} from "../../interfaces/uniswapV3/periphery/INonfungiblePositionManager.sol";
import {IStrategy} from "../../interfaces/IStrategy.sol";
import {IUserVault, Position} from "../../interfaces/IUserVault.sol";

contract UniswapV3Collect is IStrategy, OwnableUpgradeable {
    address public positionManager;

    event Collect(
        address indexed vault,
        uint256 indexed positionID
    );

    error PositionNotExists();

    function initialize(address _positionManager) external initializer {
        OwnableUpgradeable.__Ownable_init(msg.sender);
        positionManager = _positionManager;
    }

    function execute(
        address _caller,
        uint256 _positionID,
        bytes calldata _data
    ) external override returns (uint8 posType, bytes memory posData) {
        // Validate position and params
        Position memory _position = IUserVault(msg.sender).positions(
            _positionID
        );
        if (_position.data.length == 0) revert PositionNotExists();
        V3Position memory _v3Position = abi.decode(
            _position.data,
            (V3Position)
        );
        bool _userReceipt = abi.decode(_data, (bool));
        _validateParams(_caller, _userReceipt);


        // Request the position NFT
        IUserVault(msg.sender).requestERC721(positionManager, _v3Position.tokenId);

        // Recipient is the user if userReceipt is true, otherwise the vault
        address _recipient = _userReceipt ? IUserVault(msg.sender).user() : msg.sender;

        // Collect tokens
        INonfungiblePositionManager(positionManager).collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: _v3Position.tokenId,
                recipient: _recipient,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );
        
        // Transfer the NFT back to the UserVault
        IERC721(positionManager).safeTransferFrom(
            address(this),
            msg.sender,
            _v3Position.tokenId
        );

        emit Collect(msg.sender, _positionID);

        return (uint8(PositionType.V3_LP), _position.data);
    }

    function onERC721Received(
        address /* operator */,
        address /* from */,
        uint256 /* tokenId */,
        bytes calldata /* data */
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function _validateParams(address _caller, bool _userReceipt) internal view {
        address _user = IUserVault(msg.sender).user();
        if (_caller == _user) return;
        address _agent = IUserVault(msg.sender).agent();
        if (_caller != _agent) revert NotAuthorized();
        if (_userReceipt) revert NotAuthorized();
    }
}