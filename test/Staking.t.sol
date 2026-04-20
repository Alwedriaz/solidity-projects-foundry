// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";
import {MyToken} from "../src/MyToken.sol";
import {Staking} from "../src/Staking.sol";

contract StakingTest is Test {
    MyToken public token;
    Staking public staking;

    address public owner = address(this);
    address public user1 = address(1);

    uint256 public rewardRate = 1e15;

    function setUp() public {
        token = new MyToken(10000 ether);
        staking = new Staking(address(token), rewardRate);

        token.transfer(user1, 1000 ether);
        token.transfer(address(staking), 2000 ether);

        vm.prank(user1);
        token.approve(address(staking), type(uint256).max);
    }

    function test_Stake() public {
        vm.prank(user1);
        staking.stake(100 ether);

        assertEq(staking.stakedBalances(user1), 100 ether);
        assertEq(token.balanceOf(user1), 900 ether);
    }

    function test_ClaimReward() public {
        vm.prank(user1);
        staking.stake(100 ether);

        vm.warp(block.timestamp + 10);

        uint256 balanceBefore = token.balanceOf(user1);

        vm.prank(user1);
        staking.claimReward();

        uint256 balanceAfter = token.balanceOf(user1);

        assertEq(balanceAfter - balanceBefore, 1 ether);
    }

    function test_Unstake() public {
        vm.prank(user1);
        staking.stake(100 ether);

        vm.warp(block.timestamp + 10);

        vm.prank(user1);
        staking.unstake(100 ether);

        assertEq(staking.stakedBalances(user1), 0);
        assertEq(token.balanceOf(user1), 1000 ether);
        assertEq(staking.earned(user1), 1 ether);
    }

    function test_StakeFailsIfZero() public {
        vm.prank(user1);
        vm.expectRevert(bytes("Jumlah harus lebih dari 0"));
        staking.stake(0);
    }
}
