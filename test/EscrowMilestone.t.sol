// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {EscrowMilestone} from "../src/EscrowMilestone.sol";

contract EscrowMilestoneTest is Test {
    EscrowMilestone escrow;

    address buyer = address(0x1);
    address seller = address(0x2);
    address outsider = address(0x99);

    uint256 constant MILESTONE_1 = 1 ether;
    uint256 constant MILESTONE_2 = 2 ether;
    uint256 constant MILESTONE_3 = 3 ether;
    uint256 constant TOTAL_FUNDED = 6 ether;

    function setUp() public {
        vm.deal(buyer, 20 ether);
        vm.deal(seller, 0);
        vm.deal(outsider, 0);

        uint256[] memory milestoneAmounts = new uint256[](3);
        milestoneAmounts[0] = MILESTONE_1;
        milestoneAmounts[1] = MILESTONE_2;
        milestoneAmounts[2] = MILESTONE_3;

        vm.prank(buyer);
        escrow = new EscrowMilestone{value: TOTAL_FUNDED}(seller, milestoneAmounts);
    }

    function testConstructorSetsInitialValues() public view {
        assertEq(escrow.buyer(), buyer);
        assertEq(escrow.seller(), seller);
        assertEq(escrow.totalFunded(), TOTAL_FUNDED);
        assertEq(escrow.getMilestoneCount(), 3);
        assertEq(address(escrow).balance, TOTAL_FUNDED);

        (uint256 amount, bool approved, bool released) = escrow.getMilestone(0);
        assertEq(amount, MILESTONE_1);
        assertFalse(approved);
        assertFalse(released);
    }

    function testConstructorRevertsIfFundingMismatch() public {
        uint256[] memory milestoneAmounts = new uint256[](2);
        milestoneAmounts[0] = 1 ether;
        milestoneAmounts[1] = 2 ether;

        vm.prank(buyer);
        vm.expectRevert(EscrowMilestone.FundingMismatch.selector);
        new EscrowMilestone{value: 1 ether}(seller, milestoneAmounts);
    }

    function testOnlyBuyerCanApproveMilestone() public {
        vm.prank(outsider);
        vm.expectRevert(EscrowMilestone.NotBuyer.selector);
        escrow.approveMilestone(0);
    }

    function testApproveMilestoneMarksApproved() public {
        vm.prank(buyer);
        escrow.approveMilestone(1);

        (, bool approved, bool released) = escrow.getMilestone(1);
        assertTrue(approved);
        assertFalse(released);
    }

    function testReleaseRevertsIfMilestoneNotApproved() public {
        vm.prank(seller);
        vm.expectRevert(EscrowMilestone.MilestoneNotApproved.selector);
        escrow.releaseMilestone(0);
    }

    function testOnlySellerCanReleaseMilestone() public {
        vm.prank(buyer);
        escrow.approveMilestone(0);

        vm.prank(outsider);
        vm.expectRevert(EscrowMilestone.NotSeller.selector);
        escrow.releaseMilestone(0);
    }

    function testReleaseTransfersFundsToSeller() public {
        vm.prank(buyer);
        escrow.approveMilestone(0);

        uint256 sellerBalanceBefore = seller.balance;

        vm.prank(seller);
        escrow.releaseMilestone(0);

        (, bool approved, bool released) = escrow.getMilestone(0);

        assertTrue(approved);
        assertTrue(released);
        assertEq(seller.balance, sellerBalanceBefore + MILESTONE_1);
        assertEq(address(escrow).balance, TOTAL_FUNDED - MILESTONE_1);
        assertEq(escrow.totalReleased(), MILESTONE_1);
    }

    function testCannotReleaseMilestoneTwice() public {
        vm.prank(buyer);
        escrow.approveMilestone(0);

        vm.prank(seller);
        escrow.releaseMilestone(0);

        vm.prank(seller);
        vm.expectRevert(EscrowMilestone.MilestoneAlreadyReleased.selector);
        escrow.releaseMilestone(0);
    }

    function testMultipleMilestonesCanBeApprovedAndReleased() public {
        vm.prank(buyer);
        escrow.approveMilestone(0);

        vm.prank(buyer);
        escrow.approveMilestone(2);

        vm.prank(seller);
        escrow.releaseMilestone(0);

        vm.prank(seller);
        escrow.releaseMilestone(2);

        assertEq(seller.balance, MILESTONE_1 + MILESTONE_3);
        assertEq(address(escrow).balance, MILESTONE_2);
        assertEq(escrow.totalReleased(), MILESTONE_1 + MILESTONE_3);
    }

    function testBuyerCanCancelRemainingAndRefundUnapprovedBalance() public {
        vm.prank(buyer);
        escrow.approveMilestone(1);

        uint256 buyerBalanceBefore = buyer.balance;

        vm.prank(buyer);
        escrow.cancelRemaining();

        assertTrue(escrow.cancelled());
        assertEq(buyer.balance, buyerBalanceBefore + 4 ether);
        assertEq(address(escrow).balance, 2 ether);
        assertEq(escrow.getLockedApprovedAmount(), 2 ether);

        vm.prank(buyer);
        vm.expectRevert(EscrowMilestone.EscrowCancelled.selector);
        escrow.approveMilestone(0);
    }

    function testSellerCanStillReleaseAlreadyApprovedMilestoneAfterCancellation() public {
        vm.prank(buyer);
        escrow.approveMilestone(1);

        vm.prank(buyer);
        escrow.cancelRemaining();

        uint256 sellerBalanceBefore = seller.balance;

        vm.prank(seller);
        escrow.releaseMilestone(1);

        assertEq(seller.balance, sellerBalanceBefore + MILESTONE_2);
        assertEq(address(escrow).balance, 0);
    }
}
