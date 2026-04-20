// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";
import {Crowdfunding} from "../src/Crowdfunding.sol";

contract CrowdfundingTest is Test {
    Crowdfunding public crowdfunding;

    address public owner = address(100);
    address public user1 = address(1);
    address public user2 = address(2);

    uint256 public goal = 5 ether;
    uint256 public duration = 100;

    function setUp() public {
        vm.prank(owner);
        crowdfunding = new Crowdfunding(goal, duration);

        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(owner, 1 ether);
    }

    function test_Contribute() public {
        vm.prank(user1);
        crowdfunding.contribute{value: 1 ether}();

        assertEq(crowdfunding.contributions(user1), 1 ether);
        assertEq(crowdfunding.totalRaised(), 1 ether);
        assertEq(crowdfunding.getContractBalance(), 1 ether);
    }

    function test_ClaimFundsWhenGoalReached() public {
        vm.prank(user1);
        crowdfunding.contribute{value: 3 ether}();

        vm.prank(user2);
        crowdfunding.contribute{value: 2 ether}();

        vm.warp(block.timestamp + 101);

        uint256 ownerBalanceBefore = owner.balance;

        vm.prank(owner);
        crowdfunding.claimFunds();

        uint256 ownerBalanceAfter = owner.balance;

        assertEq(ownerBalanceAfter - ownerBalanceBefore, 5 ether);
        assertEq(crowdfunding.getContractBalance(), 0);
    }

    function test_RefundWhenGoalNotReached() public {
        vm.prank(user1);
        crowdfunding.contribute{value: 1 ether}();

        vm.warp(block.timestamp + 101);

        uint256 userBalanceBefore = user1.balance;

        vm.prank(user1);
        crowdfunding.refund();

        uint256 userBalanceAfter = user1.balance;

        assertEq(userBalanceAfter - userBalanceBefore, 1 ether);
        assertEq(crowdfunding.contributions(user1), 0);
        assertEq(crowdfunding.getContractBalance(), 0);
    }

    function test_ContributeFailsAfterDeadline() public {
        vm.warp(block.timestamp + 101);

        vm.prank(user1);
        vm.expectRevert(bytes("Campaign sudah berakhir"));
        crowdfunding.contribute{value: 1 ether}();
    }
}