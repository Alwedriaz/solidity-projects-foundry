// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";
import {Auction} from "../src/Auction.sol";

contract AuctionTest is Test {
    Auction public auction;

    address public owner = address(100);
    address public bidder1 = address(1);
    address public bidder2 = address(2);

    uint256 public duration = 100;

    function setUp() public {
        vm.prank(owner);
        auction = new Auction(duration);

        vm.deal(owner, 1 ether);
        vm.deal(bidder1, 10 ether);
        vm.deal(bidder2, 10 ether);
    }

    function test_FirstBid() public {
        vm.prank(bidder1);
        auction.bid{value: 1 ether}();

        assertEq(auction.highestBidder(), bidder1);
        assertEq(auction.highestBid(), 1 ether);
    }

    function test_HigherBidReplacesPreviousBidder() public {
        vm.prank(bidder1);
        auction.bid{value: 1 ether}();

        vm.prank(bidder2);
        auction.bid{value: 2 ether}();

        assertEq(auction.highestBidder(), bidder2);
        assertEq(auction.highestBid(), 2 ether);
        assertEq(auction.pendingReturns(bidder1), 1 ether);
    }

    function test_WithdrawRefund() public {
        vm.prank(bidder1);
        auction.bid{value: 1 ether}();

        vm.prank(bidder2);
        auction.bid{value: 2 ether}();

        uint256 balanceBefore = bidder1.balance;

        vm.prank(bidder1);
        auction.withdrawRefund();

        uint256 balanceAfter = bidder1.balance;

        assertEq(balanceAfter - balanceBefore, 1 ether);
        assertEq(auction.pendingReturns(bidder1), 0);
    }

    function test_CannotBidLower() public {
        vm.prank(bidder1);
        auction.bid{value: 2 ether}();

        vm.prank(bidder2);
        vm.expectRevert(bytes("Bid harus lebih tinggi"));
        auction.bid{value: 1 ether}();
    }

    function test_EndAuction() public {
        vm.prank(bidder1);
        auction.bid{value: 3 ether}();

        vm.warp(block.timestamp + duration);

        uint256 ownerBalanceBefore = owner.balance;

        vm.prank(owner);
        auction.endAuction();

        uint256 ownerBalanceAfter = owner.balance;

        assertEq(ownerBalanceAfter - ownerBalanceBefore, 3 ether);
        assertEq(auction.ended(), true);
    }

    function test_CannotEndAuctionTwice() public {
        vm.prank(bidder1);
        auction.bid{value: 1 ether}();

        vm.warp(block.timestamp + duration);

        vm.prank(owner);
        auction.endAuction();

        vm.prank(owner);
        vm.expectRevert(bytes("Auction sudah diakhiri"));
        auction.endAuction();
    }
}
