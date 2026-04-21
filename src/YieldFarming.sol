// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract YieldFarming {
    error NotOwner();
    error InvalidAddress();
    error InvalidRewardRate();
    error ZeroAmount();
    error InsufficientStakedBalance();
    error NoRewardAvailable();
    error TransferFailed();

    uint256 public constant PRECISION = 1e18;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 pendingRewards;
    }

    address public immutable owner;
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;
    uint256 public immutable rewardPerSecond;

    uint256 public totalStaked;
    uint256 public lastRewardTime;
    uint256 public accRewardPerShare;

    mapping(address => UserInfo) public userInfo;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardWithdrawn(address indexed owner, uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address _stakingToken, address _rewardToken, uint256 _rewardPerSecond) {
        if (_stakingToken == address(0) || _rewardToken == address(0)) revert InvalidAddress();
        if (_rewardPerSecond == 0) revert InvalidRewardRate();

        owner = msg.sender;
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        rewardPerSecond = _rewardPerSecond;
        lastRewardTime = block.timestamp;
    }

    function stake(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        updatePool();

        UserInfo storage user = userInfo[msg.sender];

        if (user.amount > 0) {
            uint256 accumulated = (user.amount * accRewardPerShare) / PRECISION;
            user.pendingRewards += accumulated - user.rewardDebt;
        }

        bool success = stakingToken.transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        user.amount += amount;
        totalStaked += amount;
        user.rewardDebt = (user.amount * accRewardPerShare) / PRECISION;

        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        UserInfo storage user = userInfo[msg.sender];
        if (user.amount < amount) revert InsufficientStakedBalance();

        updatePool();

        uint256 accumulated = (user.amount * accRewardPerShare) / PRECISION;
        user.pendingRewards += accumulated - user.rewardDebt;

        user.amount -= amount;
        totalStaked -= amount;
        user.rewardDebt = (user.amount * accRewardPerShare) / PRECISION;

        bool success = stakingToken.transfer(msg.sender, amount);
        if (!success) revert TransferFailed();

        emit Unstaked(msg.sender, amount);
    }

    function claimRewards() external {
        updatePool();

        UserInfo storage user = userInfo[msg.sender];

        uint256 accumulated = (user.amount * accRewardPerShare) / PRECISION;
        uint256 reward = user.pendingRewards + (accumulated - user.rewardDebt);

        if (reward == 0) revert NoRewardAvailable();

        user.pendingRewards = 0;
        user.rewardDebt = accumulated;

        bool success = rewardToken.transfer(msg.sender, reward);
        if (!success) revert TransferFailed();

        emit RewardClaimed(msg.sender, reward);
    }

    function pendingReward(address account) public view returns (uint256) {
        UserInfo memory user = userInfo[account];
        uint256 currentAccRewardPerShare = accRewardPerShare;

        if (block.timestamp > lastRewardTime && totalStaked > 0) {
            uint256 elapsed = block.timestamp - lastRewardTime;
            uint256 reward = elapsed * rewardPerSecond;
            currentAccRewardPerShare += (reward * PRECISION) / totalStaked;
        }

        uint256 accumulated = (user.amount * currentAccRewardPerShare) / PRECISION;
        return user.pendingRewards + (accumulated - user.rewardDebt);
    }

    function updatePool() public {
        if (block.timestamp <= lastRewardTime) {
            return;
        }

        if (totalStaked == 0) {
            lastRewardTime = block.timestamp;
            return;
        }

        uint256 elapsed = block.timestamp - lastRewardTime;
        uint256 reward = elapsed * rewardPerSecond;

        accRewardPerShare += (reward * PRECISION) / totalStaked;
        lastRewardTime = block.timestamp;
    }

    function getContractStakingBalance() external view returns (uint256) {
        return stakingToken.balanceOf(address(this));
    }

    function getContractRewardBalance() external view returns (uint256) {
        return rewardToken.balanceOf(address(this));
    }

    function withdrawRemainingRewards() external onlyOwner {
        uint256 balance = rewardToken.balanceOf(address(this));

        bool success = rewardToken.transfer(owner, balance);
        if (!success) revert TransferFailed();

        emit RewardWithdrawn(owner, balance);
    }
}
