// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ServiceEscrow} from "../src/ServiceEscrow.sol";

contract ServiceEscrowTest is Test {
    ServiceEscrow escrow;

    address buyer = address(0x1);
    address seller = address(0x2);
    address arbiter = address(0x3);
    address outsider = address(0x99);

    uint256 constant MILESTONE_1 = 1 ether;
    uint256 constant MILESTONE_2 = 2 ether;
    uint256 constant MILESTONE_3 = 3 ether;
    uint256 constant TOTAL_FUNDED = 6 ether;

    function setUp() public {
        vm.deal(buyer, 20 ether);
        vm.deal(seller, 0);
        vm.deal(arbiter, 0);
        vm.deal(outsider, 0);

        uint256[] memory milestoneAmounts = new uint256[](3);
        milestoneAmounts[0] = MILESTONE_1;
        milestoneAmounts[1] = MILESTONE_2;
        milestoneAmounts[2] = MILESTONE_3;

        vm.prank(buyer);
        escrow = new ServiceEscrow{value: TOTAL_FUNDED}(seller, arbiter, milestoneAmounts);
    }

    function testConstructorSetsInitialValues() public view {
        assertEq(escrow.buyer(), buyer);
        assertEq(escrow.seller(), seller);
        assertEq(escrow.arbiter(), arbiter);
        assertEq(escrow.totalFunded(), TOTAL_FUNDED);
        assertEq(escrow.getMilestoneCount(), 3);
        assertEq(address(escrow).balance, TOTAL_FUNDED);

        (
            uint256 amount,
            bool approved,
            bool disputed,
            bool resolved,
            bool released,
            bool refunded,
            uint256 sellerAward,
            uint256 buyerRefund
        ) = escrow.getMilestone(0);

        assertEq(amount, MILESTONE_1);
        assertFalse(approved);
        assertFalse(disputed);
        assertFalse(resolved);
        assertFalse(released);
        assertFalse(refunded);
        assertEq(sellerAward, 0);
        assertEq(buyerRefund, 0);
    }

    function testConstructorRevertsIfFundingMismatch() public {
        uint256[] memory milestoneAmounts = new uint256[](2);
        milestoneAmounts[0] = 1 ether;
        milestoneAmounts[1] = 2 ether;

        vm.prank(buyer);
        vm.expectRevert(ServiceEscrow.FundingMismatch.selector);
        new ServiceEscrow{value: 1 ether}(seller, arbiter, milestoneAmounts);
    }

    function testOnlyBuyerCanApproveMilestone() public {
        vm.prank(outsider);
        vm.expectRevert(ServiceEscrow.NotBuyer.selector);
        escrow.approveMilestone(0);
    }

    function testApproveMilestoneMarksApproved() public {
        vm.prank(buyer);
        escrow.approveMilestone(1);

        (, bool approved,,,,,,) = escrow.getMilestone(1);
        assertTrue(approved);
    }

    function testOnlySellerCanClaimMilestone() public {
        vm.prank(buyer);
        escrow.approveMilestone(0);

        vm.prank(outsider);
        vm.expectRevert(ServiceEscrow.NotSeller.selector);
        escrow.claimMilestone(0);
    }

    function testSellerCanClaimApprovedMilestone() public {
        vm.prank(buyer);
        escrow.approveMilestone(0);

        uint256 sellerBalanceBefore = seller.balance;

        vm.prank(seller);
        escrow.claimMilestone(0);

        (, bool approved,,, bool released, bool refunded, uint256 sellerAward, uint256 buyerRefund) =
            escrow.getMilestone(0);

        assertTrue(approved);
        assertTrue(released);
        assertFalse(refunded);
        assertEq(sellerAward, MILESTONE_1);
        assertEq(buyerRefund, 0);
        assertEq(seller.balance, sellerBalanceBefore + MILESTONE_1);
        assertEq(address(escrow).balance, TOTAL_FUNDED - MILESTONE_1);
        assertEq(escrow.totalReleased(), MILESTONE_1);
    }

    function testCannotClaimMilestoneTwice() public {
        vm.prank(buyer);
        escrow.approveMilestone(0);

        vm.prank(seller);
        escrow.claimMilestone(0);

        vm.prank(seller);
        vm.expectRevert(ServiceEscrow.MilestoneAlreadyReleased.selector);
        escrow.claimMilestone(0);
    }

    function testBuyerCanOpenDispute() public {
        vm.prank(buyer);
        escrow.openDispute(1);

        (,, bool disputed,,,,,) = escrow.getMilestone(1);
        assertTrue(disputed);
    }

    function testOnlyBuyerCanOpenDispute() public {
        vm.prank(outsider);
        vm.expectRevert(ServiceEscrow.NotBuyer.selector);
        escrow.openDispute(0);
    }

    function testOnlyArbiterCanResolveDispute() public {
        vm.prank(buyer);
        escrow.openDispute(1);

        vm.prank(outsider);
        vm.expectRevert(ServiceEscrow.NotArbiter.selector);
        escrow.resolveDispute(1, true);
    }

    function testArbiterCanResolveDisputeInFavorOfSeller() public {
        vm.prank(buyer);
        escrow.openDispute(1);

        uint256 sellerBalanceBefore = seller.balance;

        vm.prank(arbiter);
        escrow.resolveDispute(1, true);

        (,, bool disputed, bool resolved, bool released, bool refunded, uint256 sellerAward, uint256 buyerRefund) =
            escrow.getMilestone(1);

        assertTrue(disputed);
        assertTrue(resolved);
        assertTrue(released);
        assertFalse(refunded);
        assertEq(sellerAward, MILESTONE_2);
        assertEq(buyerRefund, 0);
        assertEq(seller.balance, sellerBalanceBefore + MILESTONE_2);
        assertEq(address(escrow).balance, TOTAL_FUNDED - MILESTONE_2);
        assertEq(escrow.totalReleased(), MILESTONE_2);
    }

    function testArbiterCanResolveDisputeInFavorOfBuyer() public {
        vm.prank(buyer);
        escrow.openDispute(2);

        uint256 buyerBalanceBefore = buyer.balance;

        vm.prank(arbiter);
        escrow.resolveDispute(2, false);

        (,, bool disputed, bool resolved, bool released, bool refunded, uint256 sellerAward, uint256 buyerRefund) =
            escrow.getMilestone(2);

        assertTrue(disputed);
        assertTrue(resolved);
        assertFalse(released);
        assertTrue(refunded);
        assertEq(sellerAward, 0);
        assertEq(buyerRefund, MILESTONE_3);
        assertEq(buyer.balance, buyerBalanceBefore + MILESTONE_3);
        assertEq(address(escrow).balance, TOTAL_FUNDED - MILESTONE_3);
        assertEq(escrow.totalRefunded(), MILESTONE_3);
    }

    function testArbiterCanResolveDisputeWithPartialSplit() public {
        vm.prank(buyer);
        escrow.openDispute(1);

        uint256 sellerBalanceBefore = seller.balance;
        uint256 buyerBalanceBefore = buyer.balance;

        uint256 sellerPortion = 15 ether / 10; // 1.5 ether from milestone 2 ether

        vm.prank(arbiter);
        escrow.resolveDisputeSplit(1, sellerPortion);

        (,, bool disputed, bool resolved, bool released, bool refunded, uint256 sellerAward, uint256 buyerRefund) =
            escrow.getMilestone(1);

        assertTrue(disputed);
        assertTrue(resolved);
        assertTrue(released);
        assertTrue(refunded);
        assertEq(sellerAward, sellerPortion);
        assertEq(buyerRefund, MILESTONE_2 - sellerPortion);

        assertEq(seller.balance, sellerBalanceBefore + sellerPortion);
        assertEq(buyer.balance, buyerBalanceBefore + (MILESTONE_2 - sellerPortion));

        assertEq(escrow.totalReleased(), sellerPortion);
        assertEq(escrow.totalRefunded(), MILESTONE_2 - sellerPortion);
        assertEq(address(escrow).balance, TOTAL_FUNDED - MILESTONE_2);
    }

    function testResolveSplitRevertsIfSellerAmountTooHigh() public {
        vm.prank(buyer);
        escrow.openDispute(0);

        vm.prank(arbiter);
        vm.expectRevert(ServiceEscrow.InvalidResolutionAmount.selector);
        escrow.resolveDisputeSplit(0, MILESTONE_1 + 1);
    }

    function testCannotApproveDisputedMilestone() public {
        vm.prank(buyer);
        escrow.openDispute(0);

        vm.prank(buyer);
        vm.expectRevert(ServiceEscrow.MilestoneAlreadyDisputed.selector);
        escrow.approveMilestone(0);
    }

    function testCannotOpenDisputeAfterClaim() public {
        vm.prank(buyer);
        escrow.approveMilestone(0);

        vm.prank(seller);
        escrow.claimMilestone(0);

        vm.prank(buyer);
        vm.expectRevert(ServiceEscrow.MilestoneAlreadyReleased.selector);
        escrow.openDispute(0);
    }
}
