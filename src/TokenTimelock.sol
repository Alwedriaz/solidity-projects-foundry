// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenTimelock {
    error NotOwner();
    error NotBeneficiary();
    error ZeroAddress();
    error ZeroAmount();
    error UnlockTimeInPast();
    error UnlockTimeNotReached();
    error TimelockExpired();
    error NothingToRelease();
    error TransferFailed();

    address public immutable owner;
    IERC20 public immutable token;
    address public immutable beneficiary;
    uint256 public immutable unlockTime;

    uint256 public totalLocked;
    uint256 public totalReleased;

    event Deposited(address indexed owner, uint256 amount);
    event Released(address indexed beneficiary, uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyBeneficiary() {
        if (msg.sender != beneficiary) revert NotBeneficiary();
        _;
    }

    constructor(address _token, address _beneficiary, uint256 _unlockTime) {
        if (_token == address(0) || _beneficiary == address(0)) revert ZeroAddress();
        if (_unlockTime <= block.timestamp) revert UnlockTimeInPast();

        owner = msg.sender;
        token = IERC20(_token);
        beneficiary = _beneficiary;
        unlockTime = _unlockTime;
    }

    function deposit(uint256 amount) external onlyOwner {
        if (block.timestamp >= unlockTime) revert TimelockExpired();
        if (amount == 0) revert ZeroAmount();

        totalLocked += amount;

        bool success = token.transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        emit Deposited(msg.sender, amount);
    }

    function release() external onlyBeneficiary {
        if (block.timestamp < unlockTime) revert UnlockTimeNotReached();

        uint256 balance = token.balanceOf(address(this));
        if (balance == 0) revert NothingToRelease();

        totalReleased += balance;

        bool success = token.transfer(beneficiary, balance);
        if (!success) revert TransferFailed();

        emit Released(beneficiary, balance);
    }

    function getContractTokenBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}
