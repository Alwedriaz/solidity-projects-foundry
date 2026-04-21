// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ERC20StakingPool {
    error NotOwner();
    error ZeroAmount();
    error InsufficientStakedBalance();
    error NoRewardAvailable();
    error InvalidAddress();
    error InvalidRewardRate();
    error TransferFailed();

    uint256 public constant PRECISION = 1e18;

    address public immutable owner;
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;
    uint256 public immutable rewardRatePerSecond;

    uint256 public totalStaked;

    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public lastUpdatedAt;
    mapping(address => uint256) public unclaimedRewards;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardWithdrawn(address indexed owner, uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address _stakingToken, address _rewardToken, uint256 _rewardRatePerSecond) {
        if (_stakingToken == address(0) || _rewardToken == address(0)) revert InvalidAddress();
        if (_rewardRatePerSecond == 0) revert InvalidRewardRate();

        owner = msg.sender;
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        rewardRatePerSecond = _rewardRatePerSecond;
    }

    function stake(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        _updateReward(msg.sender);

        bool success = stakingToken.transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        stakedBalance[msg.sender] += amount;
        totalStaked += amount;

        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (stakedBalance[msg.sender] < amount) revert InsufficientStakedBalance();

        _updateReward(msg.sender);

        stakedBalance[msg.sender] -= amount;
        totalStaked -= amount;

        bool success = stakingToken.transfer(msg.sender, amount);
        if (!success) revert TransferFailed();

        emit Unstaked(msg.sender, amount);
    }

    function claimRewards() external {
        _updateReward(msg.sender);

        uint256 reward = unclaimedRewards[msg.sender];
        if (reward == 0) revert NoRewardAvailable();

        unclaimedRewards[msg.sender] = 0;

        bool success = rewardToken.transfer(msg.sender, reward);
        if (!success) revert TransferFailed();

        emit RewardClaimed(msg.sender, reward);
    }

    function pendingReward(address account) public view returns (uint256) {
        uint256 reward = unclaimedRewards[account];
        uint256 balance = stakedBalance[account];
        uint256 lastTime = lastUpdatedAt[account];

        if (balance == 0 || lastTime == 0) {
            return reward;
        }

        uint256 elapsed = block.timestamp - lastTime;
        uint256 accrued = (balance * elapsed * rewardRatePerSecond) / PRECISION;

        return reward + accrued;
    }

    function getContractRewardBalance() external view returns (uint256) {
        return rewardToken.balanceOf(address(this));
    }

    function getContractStakingBalance() external view returns (uint256) {
        return stakingToken.balanceOf(address(this));
    }

    function withdrawRemainingRewards() external onlyOwner {
        uint256 balance = rewardToken.balanceOf(address(this));

        bool success = rewardToken.transfer(owner, balance);
        if (!success) revert TransferFailed();

        emit RewardWithdrawn(owner, balance);
    }

    function _updateReward(address account) internal {
        uint256 lastTime = lastUpdatedAt[account];

        if (lastTime == 0) {
            lastUpdatedAt[account] = block.timestamp;
            return;
        }

        uint256 balance = stakedBalance[account];

        if (balance > 0) {
            uint256 elapsed = block.timestamp - lastTime;
            if (elapsed > 0) {
                unclaimedRewards[account] += (balance * elapsed * rewardRatePerSecond) / PRECISION;
            }
        }

        lastUpdatedAt[account] = block.timestamp;
    }
}
