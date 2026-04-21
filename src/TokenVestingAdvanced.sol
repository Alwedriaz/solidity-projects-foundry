// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenVestingAdvanced {
    error NotOwner();
    error NotBeneficiary();
    error ZeroAddress();
    error InvalidSchedule();
    error InvalidAllocation();
    error NothingToRelease();
    error NotRevocable();
    error AlreadyRevoked();
    error TransferFailed();

    address public immutable owner;
    IERC20 public immutable token;
    address public immutable beneficiary;

    uint256 public immutable totalAllocation;
    uint256 public immutable start;
    uint256 public immutable cliff;
    uint256 public immutable duration;
    bool public immutable revocable;

    uint256 public released;
    bool public revoked;
    uint256 public revokedAt;

    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed owner, uint256 refundedAmount);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyBeneficiary() {
        if (msg.sender != beneficiary) revert NotBeneficiary();
        _;
    }

    constructor(
        address _token,
        address _beneficiary,
        uint256 _totalAllocation,
        uint256 _start,
        uint256 _cliffDuration,
        uint256 _duration,
        bool _revocable
    ) {
        if (_token == address(0) || _beneficiary == address(0)) revert ZeroAddress();
        if (_totalAllocation == 0) revert InvalidAllocation();
        if (_duration == 0 || _cliffDuration > _duration) revert InvalidSchedule();

        owner = msg.sender;
        token = IERC20(_token);
        beneficiary = _beneficiary;
        totalAllocation = _totalAllocation;
        start = _start;
        cliff = _start + _cliffDuration;
        duration = _duration;
        revocable = _revocable;
    }

    function release() external onlyBeneficiary {
        uint256 amount = releasableAmount();
        if (amount == 0) revert NothingToRelease();

        released += amount;

        bool success = token.transfer(beneficiary, amount);
        if (!success) revert TransferFailed();

        emit TokensReleased(beneficiary, amount);
    }

    function revoke() external onlyOwner {
        if (!revocable) revert NotRevocable();
        if (revoked) revert AlreadyRevoked();

        uint256 vested = vestedAmount(block.timestamp);
        uint256 unvested = totalAllocation - vested;

        revoked = true;
        revokedAt = block.timestamp;

        if (unvested > 0) {
            bool success = token.transfer(owner, unvested);
            if (!success) revert TransferFailed();
        }

        emit VestingRevoked(owner, unvested);
    }

    function releasableAmount() public view returns (uint256) {
        return vestedAmount(block.timestamp) - released;
    }

    function vestedAmount(uint256 timestamp) public view returns (uint256) {
        if (timestamp < cliff) {
            return 0;
        }

        uint256 effectiveTime = timestamp;

        if (revoked && timestamp > revokedAt) {
            effectiveTime = revokedAt;
        }

        if (effectiveTime >= start + duration) {
            return totalAllocation;
        }

        return (totalAllocation * (effectiveTime - start)) / duration;
    }

    function getUnreleasedBalance() external view returns (uint256) {
        return totalAllocation - released;
    }

    function getContractTokenBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}
