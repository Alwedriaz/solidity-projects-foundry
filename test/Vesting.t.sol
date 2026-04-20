// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Vesting} from "../src/Vesting.sol";

contract VestingTest is Test {
    Vesting public vesting;
    address public beneficiary = address(1);

    uint256 public startTime;
    uint256 public duration = 100;

    function setUp() public {
        startTime = block.timestamp + 10;

        vesting = new Vesting{value: 10 ether}(
            beneficiary,
            startTime,
            duration
        );
    }

    function test_NoReleaseBeforeStart() public {
        vm.deal(beneficiary, 1 ether);

        vm.prank(beneficiary);
        vm.expectRevert("Belum ada dana yang bisa dicairkan");
        vesting.release();
    }

    function test_PartialReleaseHalfway() public {
        vm.warp(startTime + 50);

        uint256 balanceBefore = beneficiary.balance;

        vm.prank(beneficiary);
        vesting.release();

        uint256 balanceAfter = beneficiary.balance;

        assertEq(balanceAfter - balanceBefore, 5 ether);
        assertEq(vesting.getContractBalance(), 5 ether);
    }

    function test_FullReleaseAfterDuration() public {
        vm.warp(startTime + duration);

        uint256 balanceBefore = beneficiary.balance;

        vm.prank(beneficiary);
        vesting.release();

        uint256 balanceAfter = beneficiary.balance;

        assertEq(balanceAfter - balanceBefore, 10 ether);
        assertEq(vesting.getContractBalance(), 0);
    }

    function test_ReleaseFailsIfNotBeneficiary() public {
        address otherUser = address(2);
        vm.deal(otherUser, 1 ether);

        vm.warp(startTime + 50);

        vm.prank(otherUser);
        vm.expectRevert("Hanya beneficiary yang bisa release");
        vesting.release();
    }
}