// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenFaucet {
    error NotOwner();
    error InvalidAddress();
    error InvalidAmount();
    error InvalidCooldown();
    error ClaimTooSoon();
    error InsufficientFaucetBalance();
    error NothingToWithdraw();
    error TransferFailed();

    address public immutable owner;
    IERC20 public immutable token;
    uint256 public immutable faucetAmount;
    uint256 public immutable cooldown;

    mapping(address => uint256) public lastClaimedAt;

    event Claimed(address indexed user, uint256 amount, uint256 timestamp);
    event Withdrawn(address indexed owner, uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address _token, uint256 _faucetAmount, uint256 _cooldown) {
        if (_token == address(0)) revert InvalidAddress();
        if (_faucetAmount == 0) revert InvalidAmount();
        if (_cooldown == 0) revert InvalidCooldown();

        owner = msg.sender;
        token = IERC20(_token);
        faucetAmount = _faucetAmount;
        cooldown = _cooldown;
    }

    function claim() external {
        uint256 lastClaim = lastClaimedAt[msg.sender];

        if (lastClaim != 0 && block.timestamp < lastClaim + cooldown) {
            revert ClaimTooSoon();
        }

        if (token.balanceOf(address(this)) < faucetAmount) {
            revert InsufficientFaucetBalance();
        }

        lastClaimedAt[msg.sender] = block.timestamp;

        bool success = token.transfer(msg.sender, faucetAmount);
        if (!success) revert TransferFailed();

        emit Claimed(msg.sender, faucetAmount, block.timestamp);
    }

    function withdrawRemainingTokens() external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        if (balance == 0) revert NothingToWithdraw();

        bool success = token.transfer(owner, balance);
        if (!success) revert TransferFailed();

        emit Withdrawn(owner, balance);
    }

    function getContractTokenBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function canClaim(address user) external view returns (bool) {
        uint256 lastClaim = lastClaimedAt[user];

        if (lastClaim == 0) {
            return token.balanceOf(address(this)) >= faucetAmount;
        }

        return block.timestamp >= lastClaim + cooldown && token.balanceOf(address(this)) >= faucetAmount;
    }
}
