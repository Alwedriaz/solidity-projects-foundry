// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.33;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Staking {
    IERC20 public immutable TOKEN;
    uint256 public immutable REWARD_RATE;

    mapping(address => uint256) public stakedBalances;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public lastUpdated;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);

    constructor(address _token, uint256 _rewardRate) {
        require(_token != address(0), "Token tidak valid");
        require(_rewardRate > 0, "Reward rate harus lebih dari 0");

        TOKEN = IERC20(_token);
        REWARD_RATE = _rewardRate;
    }

    function earned(address user) public view returns (uint256) {
        if (lastUpdated[user] == 0) {
            return rewards[user];
        }

        uint256 elapsed = block.timestamp - lastUpdated[user];
        uint256 pending = (elapsed * stakedBalances[user] * REWARD_RATE) / 1e18;

        return rewards[user] + pending;
    }

    function stake(uint256 amount) public {
        require(amount > 0, "Jumlah harus lebih dari 0");

        _updateReward(msg.sender);
        stakedBalances[msg.sender] += amount;

        bool success = TOKEN.transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer gagal");

        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) public {
        require(amount > 0, "Jumlah harus lebih dari 0");
        require(stakedBalances[msg.sender] >= amount, "Saldo stake tidak cukup");

        _updateReward(msg.sender);
        stakedBalances[msg.sender] -= amount;

        bool success = TOKEN.transfer(msg.sender, amount);
        require(success, "Transfer gagal");

        emit Unstaked(msg.sender, amount);
    }

    function claimReward() public {
        _updateReward(msg.sender);

        uint256 reward = rewards[msg.sender];
        require(reward > 0, "Tidak ada reward");

        rewards[msg.sender] = 0;

        bool success = TOKEN.transfer(msg.sender, reward);
        require(success, "Transfer gagal");

        emit RewardClaimed(msg.sender, reward);
    }

    function _updateReward(address user) internal {
        rewards[user] = earned(user);
        lastUpdated[user] = block.timestamp;
    }
}
