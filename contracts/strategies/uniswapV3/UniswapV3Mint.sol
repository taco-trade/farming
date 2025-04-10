// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {IManager} from "../../interfaces/IManager.sol";
import {INonfungiblePositionManager} from "../../interfaces/uniswapV3/periphery/INonfungiblePositionManager.sol";
import {IStrategy} from "../../interfaces/IStrategy.sol";
import {IUserVault, Position} from "../../interfaces/IUserVault.sol";

contract UniswapV3Mint is
    IStrategy,
    IERC721Receiver,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    address public positionManager;

    event Mint(
        address indexed vault,
        uint256 indexed positionID,
        uint256 indexed tokenID,
        address token0,
        address token1,
        uint128 liquidity,
        uint256 token0Amount,
        uint256 token1Amount
    );

    error PositionAlreadyExists();
    error InvalidTokenOrder();

    function initialize(
        address _positionManager
    ) external initializer {
        OwnableUpgradeable.__Ownable_init(msg.sender);
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        positionManager = _positionManager;
    }

    function execute(
        address _caller,
        uint256 _positionID,
        bytes calldata _data
    )
        external
        override
        nonReentrant
        returns (uint8 posType, bytes memory posData)
    {
        Position memory _position = IUserVault(msg.sender).positions(_positionID);
        if (_position.data.length != 0) revert PositionAlreadyExists();

        (
            bool _userFund,
            INonfungiblePositionManager.MintParams memory _params
        ) = abi.decode(
                _data,
                (bool, INonfungiblePositionManager.MintParams)
            );
        if (_params.token0 >= _params.token1) revert InvalidTokenOrder();

        if (!_validateAgent(_caller, _userFund)) {
            revert NotAuthorized();
        }

        SafeERC20.safeIncreaseAllowance(
            IERC20(_params.token0),
            positionManager,
            _params.amount0Desired
        );
        SafeERC20.safeIncreaseAllowance(
            IERC20(_params.token1),
            positionManager,
            _params.amount1Desired
        );

        if (_userFund) {
            IUserVault(msg.sender).requestFundsFromUser(
                _params.token0,
                _params.amount0Desired
            );
            IUserVault(msg.sender).requestFundsFromUser(
                _params.token1,
                _params.amount1Desired
            );
        } else {
            IUserVault(msg.sender).requestFunds(
                _params.token0,
                _params.amount0Desired
            );
            IUserVault(msg.sender).requestFunds(
                _params.token1,
                _params.amount1Desired
            );
        }

        _params.recipient = msg.sender;
        _params.deadline = block.timestamp;

        (uint256 _tokenID, uint128 _liquidity, uint256 _amount0, uint256 _amount1) = INonfungiblePositionManager(positionManager)
            .mint(_params);

        emit Mint(
            msg.sender,
            _positionID,
            _tokenID,
            _params.token0,
            _params.token1,
            _liquidity,
            _amount0,
            _amount1
        );
        return (
            uint8(PositionType.V3_LP),
            abi.encode(
                V3Position({
                    tokenId: _tokenID,
                    token0: _params.token0,
                    token1: _params.token1,
                    fee: _params.fee
                })
            )
        );
    }

    function onERC721Received(
        address /* operator */,
        address /* from */,
        uint256 /* tokenId */,
        bytes calldata /* data */
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /// @notice Validate the agent behavior
    /// @param _caller The caller address
    /// @param _userFund The user fund flag
    /// @return True if the agent behavior is valid, false otherwise
    /// @dev If the caller is the agent, the fund source must be the vault and the pool must be approved
    function _validateAgent(
        address _caller,
        bool _userFund
    ) internal view returns (bool) {
        address _vault = msg.sender;
        if (_caller == IUserVault(_vault).user()) {
            return true;
        }

        if (_caller != IUserVault(_vault).agent()) {
            return false;
        }

        if (_userFund) {
            return false;
        }
        return true;
    }
}
