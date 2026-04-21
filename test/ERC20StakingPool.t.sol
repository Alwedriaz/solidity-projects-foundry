// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20StakingPool} from "../src/ERC20StakingPool.sol";

contract MockStakeToken is ERC20 {
    constructor() ERC20("Mock Stake Token", "MST") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockRewardTokenPool is ERC20 {
    constructor() ERC20("Mock Reward Token", "MRT") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract ERC20StakingPoolTest is Test {
    MockStakeToken stakeToken;
    MockRewardTokenPool rewardToken;
    ERC20StakingPool pool;

    address owner = address(this);
    address user1 = address(0x1);
    address user2 = address(0x2);
    address outsider = address(0x99);

    uint256 constant REWARD_RATE = 1e16; // 0.01 reward token per staked token per second
    uint256 constant INITIAL_STAKE = 100 ether;

    function setUp() public {
        stakeToken = new MockStakeToken();
        rewardToken = new MockRewardTokenPool();

        pool = new ERC20StakingPool(address(stakeToken), address(rewardToken), REWARD_RATE);

        stakeToken.mint(user1, 1000 ether);
        stakeToken.mint(user2, 1000 ether);
        rewardToken.mint(address(pool), 100000 ether);
    }

    function testConstructorSetsInitialValues() public view {
        assertEq(pool.owner(), owner);
        assertEq(address(pool.stakingToken()), address(stakeToken));
        assertEq(address(pool.rewardToken()), address(rewardToken));
        assertEq(pool.rewardRatePerSecond(), REWARD_RATE);
        assertEq(pool.totalStaked(), 0);
    }

    function testStakeTransfersTokensAndUpdatesBalance() public {
        vm.startPrank(user1);
        stakeToken.approve(address(pool), INITIAL_STAKE);
        pool.stake(INITIAL_STAKE);
        vm.stopPrank();

        assertEq(pool.stakedBalance(user1), INITIAL_STAKE);
        assertEq(pool.totalStaked(), INITIAL_STAKE);
        assertEq(stakeToken.balanceOf(address(pool)), INITIAL_STAKE);
        assertEq(stakeToken.balanceOf(user1), 900 ether);
    }

    function testStakeRevertsIfAmountZero() public {
        vm.prank(user1);
        vm.expectRevert(ERC20StakingPool.ZeroAmount.selector);
        pool.stake(0);
    }

    function testClaimRewardsAfterTimePasses() public {
        vm.startPrank(user1);
        stakeToken.approve(address(pool), INITIAL_STAKE);
        pool.stake(INITIAL_STAKE);

        vm.warp(block.timestamp + 10);

        pool.claimRewards();
        vm.stopPrank();

        assertEq(rewardToken.balanceOf(user1), 10 ether);
        assertEq(pool.unclaimedRewards(user1), 0);
        assertEq(pool.pendingReward(user1), 0);
    }

    function testClaimRewardsRevertsIfNoRewardAvailable() public {
        vm.startPrank(user1);
        stakeToken.approve(address(pool), INITIAL_STAKE);
        pool.stake(INITIAL_STAKE);

        vm.expectRevert(ERC20StakingPool.NoRewardAvailable.selector);
        pool.claimRewards();
        vm.stopPrank();
    }

    function testMultipleStakesKeepRewardAccountingCorrect() public {
        vm.startPrank(user1);
        stakeToken.approve(address(pool), 200 ether);
        pool.stake(100 ether);

        vm.warp(block.timestamp + 10);

        pool.stake(100 ether);

        vm.warp(block.timestamp + 10);

        pool.claimRewards();
        vm.stopPrank();

        assertEq(rewardToken.balanceOf(user1), 30 ether);
        assertEq(pool.stakedBalance(user1), 200 ether);
    }

    function testUnstakeReturnsTokensAndPreservesAccruedRewards() public {
        vm.startPrank(user1);
        stakeToken.approve(address(pool), INITIAL_STAKE);
        pool.stake(INITIAL_STAKE);

        vm.warp(block.timestamp + 10);

        pool.unstake(40 ether);

        assertEq(pool.stakedBalance(user1), 60 ether);
        assertEq(stakeToken.balanceOf(user1), 940 ether);
        assertEq(pool.pendingReward(user1), 10 ether);

        pool.claimRewards();
        vm.stopPrank();

        assertEq(rewardToken.balanceOf(user1), 10 ether);
    }

    function testUnstakeRevertsIfAmountTooHigh() public {
        vm.startPrank(user1);
        stakeToken.approve(address(pool), INITIAL_STAKE);
        pool.stake(INITIAL_STAKE);

        vm.expectRevert(ERC20StakingPool.InsufficientStakedBalance.selector);
        pool.unstake(200 ether);
        vm.stopPrank();
    }

    function testDifferentUsersEarnRewardsIndependently() public {
        vm.startPrank(user1);
        stakeToken.approve(address(pool), 100 ether);
        pool.stake(100 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 10);

        vm.startPrank(user2);
        stakeToken.approve(address(pool), 50 ether);
        pool.stake(50 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 10);

        assertEq(pool.pendingReward(user1), 20 ether);
        assertEq(pool.pendingReward(user2), 5 ether);
    }

    function testOnlyOwnerCanWithdrawRemainingRewards() public {
        vm.prank(outsider);
        vm.expectRevert(ERC20StakingPool.NotOwner.selector);
        pool.withdrawRemainingRewards();
    }

    function testOwnerCanWithdrawRemainingRewards() public {
        uint256 ownerBalanceBefore = rewardToken.balanceOf(owner);
        uint256 contractBalanceBefore = rewardToken.balanceOf(address(pool));

        pool.withdrawRemainingRewards();

        assertEq(rewardToken.balanceOf(address(pool)), 0);
        assertEq(rewardToken.balanceOf(owner), ownerBalanceBefore + contractBalanceBefore);
    }
}
