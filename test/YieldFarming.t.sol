// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {YieldFarming} from "../src/YieldFarming.sol";

contract MockLPToken is ERC20 {
    constructor() ERC20("Mock LP Token", "MLP") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockFarmRewardToken is ERC20 {
    constructor() ERC20("Mock Farm Reward", "MFR") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract YieldFarmingTest is Test {
    MockLPToken lpToken;
    MockFarmRewardToken rewardToken;
    YieldFarming farm;

    address owner = address(this);
    address user1 = address(0x1);
    address user2 = address(0x2);
    address outsider = address(0x99);

    uint256 constant REWARD_PER_SECOND = 1 ether;

    function setUp() public {
        lpToken = new MockLPToken();
        rewardToken = new MockFarmRewardToken();

        farm = new YieldFarming(address(lpToken), address(rewardToken), REWARD_PER_SECOND);

        lpToken.mint(user1, 1000 ether);
        lpToken.mint(user2, 1000 ether);
        rewardToken.mint(address(farm), 100000 ether);
    }

    function testConstructorSetsInitialValues() public view {
        assertEq(farm.owner(), owner);
        assertEq(address(farm.stakingToken()), address(lpToken));
        assertEq(address(farm.rewardToken()), address(rewardToken));
        assertEq(farm.rewardPerSecond(), REWARD_PER_SECOND);
        assertEq(farm.totalStaked(), 0);
    }

    function testStakeTransfersTokensAndUpdatesBalance() public {
        vm.startPrank(user1);
        lpToken.approve(address(farm), 100 ether);
        farm.stake(100 ether);
        vm.stopPrank();

        (uint256 amount,,) = farm.userInfo(user1);

        assertEq(amount, 100 ether);
        assertEq(farm.totalStaked(), 100 ether);
        assertEq(lpToken.balanceOf(address(farm)), 100 ether);
        assertEq(lpToken.balanceOf(user1), 900 ether);
    }

    function testStakeRevertsIfZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(YieldFarming.ZeroAmount.selector);
        farm.stake(0);
    }

    function testClaimRewardsAfterTimePasses() public {
        vm.startPrank(user1);
        lpToken.approve(address(farm), 100 ether);
        farm.stake(100 ether);

        vm.warp(block.timestamp + 10);

        farm.claimRewards();
        vm.stopPrank();

        assertEq(rewardToken.balanceOf(user1), 10 ether);
        assertEq(farm.pendingReward(user1), 0);
    }

    function testClaimRewardsRevertsIfNoRewardAvailable() public {
        vm.startPrank(user1);
        lpToken.approve(address(farm), 100 ether);
        farm.stake(100 ether);

        vm.expectRevert(YieldFarming.NoRewardAvailable.selector);
        farm.claimRewards();
        vm.stopPrank();
    }

    function testMultipleUsersShareRewardsProportionally() public {
        vm.startPrank(user1);
        lpToken.approve(address(farm), 100 ether);
        farm.stake(100 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 10);

        vm.startPrank(user2);
        lpToken.approve(address(farm), 100 ether);
        farm.stake(100 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 10);

        assertEq(farm.pendingReward(user1), 15 ether);
        assertEq(farm.pendingReward(user2), 5 ether);
    }

    function testUnstakeReturnsTokensAndPreservesRewards() public {
        vm.startPrank(user1);
        lpToken.approve(address(farm), 100 ether);
        farm.stake(100 ether);

        vm.warp(block.timestamp + 10);

        farm.unstake(40 ether);

        assertEq(lpToken.balanceOf(user1), 940 ether);
        assertEq(farm.pendingReward(user1), 10 ether);

        farm.claimRewards();
        vm.stopPrank();

        assertEq(rewardToken.balanceOf(user1), 10 ether);

        (uint256 amount,,) = farm.userInfo(user1);
        assertEq(amount, 60 ether);
    }

    function testUnstakeRevertsIfAmountTooHigh() public {
        vm.startPrank(user1);
        lpToken.approve(address(farm), 100 ether);
        farm.stake(100 ether);

        vm.expectRevert(YieldFarming.InsufficientStakedBalance.selector);
        farm.unstake(200 ether);
        vm.stopPrank();
    }

    function testOnlyOwnerCanWithdrawRemainingRewards() public {
        vm.prank(outsider);
        vm.expectRevert(YieldFarming.NotOwner.selector);
        farm.withdrawRemainingRewards();
    }

    function testOwnerCanWithdrawRemainingRewards() public {
        uint256 ownerBalanceBefore = rewardToken.balanceOf(owner);
        uint256 contractBalanceBefore = rewardToken.balanceOf(address(farm));

        farm.withdrawRemainingRewards();

        assertEq(rewardToken.balanceOf(address(farm)), 0);
        assertEq(rewardToken.balanceOf(owner), ownerBalanceBefore + contractBalanceBefore);
    }
}
