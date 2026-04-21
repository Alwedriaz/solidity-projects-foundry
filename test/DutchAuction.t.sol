// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DutchAuction} from "../src/DutchAuction.sol";

contract DutchAuctionTest is Test {
    DutchAuction auction;

    address seller = address(0xA11CE);
    address buyer1 = address(0x1);
    address buyer2 = address(0x2);

    uint256 constant STARTING_PRICE = 10 ether;
    uint256 constant DISCOUNT_RATE = 0.1 ether;
    uint256 constant DURATION = 50;

    function setUp() public {
        vm.deal(seller, 0);
        vm.deal(buyer1, 20 ether);
        vm.deal(buyer2, 20 ether);

        vm.prank(seller);
        auction = new DutchAuction(STARTING_PRICE, DISCOUNT_RATE, DURATION);
    }

    function testConstructorSetsInitialValues() public view {
        assertEq(auction.seller(), seller);
        assertEq(auction.startingPrice(), STARTING_PRICE);
        assertEq(auction.discountRate(), DISCOUNT_RATE);
        assertEq(auction.expiresAt(), auction.startAt() + DURATION);
        assertFalse(auction.ended());
    }

    function testConstructorRevertsIfConfigInvalid() public {
        vm.prank(seller);
        vm.expectRevert(DutchAuction.InvalidAuctionConfig.selector);
        new DutchAuction(1 ether, 1 ether, 2);
    }

    function testCurrentPriceDecreasesOverTime() public {
        vm.warp(auction.startAt() + 10);

        assertEq(auction.getCurrentPrice(), 9 ether);
    }

    function testCurrentPriceStopsAtExpiryFloor() public {
        vm.warp(auction.expiresAt() + 100);

        assertEq(auction.getCurrentPrice(), 5 ether);
    }

    function testBuyRevertsIfPaymentTooLow() public {
        vm.prank(buyer1);
        vm.expectRevert(DutchAuction.InsufficientPayment.selector);
        auction.buy{value: 1 ether}();
    }

    function testBuyTransfersFundsToSellerAndRefundsExcess() public {
        vm.warp(auction.startAt() + 10);

        uint256 price = auction.getCurrentPrice();
        uint256 sellerBalanceBefore = seller.balance;
        uint256 buyerBalanceBefore = buyer1.balance;

        vm.prank(buyer1);
        auction.buy{value: 10 ether}();

        assertTrue(auction.ended());
        assertEq(auction.winner(), buyer1);
        assertEq(auction.finalPrice(), price);

        assertEq(seller.balance, sellerBalanceBefore + price);
        assertEq(buyer1.balance, buyerBalanceBefore - price);
        assertEq(address(auction).balance, 0);
    }

    function testCannotBuyTwice() public {
        vm.prank(buyer1);
        auction.buy{value: STARTING_PRICE}();

        vm.prank(buyer2);
        vm.expectRevert(DutchAuction.AuctionEnded.selector);
        auction.buy{value: STARTING_PRICE}();
    }

    function testBuyRevertsAfterExpiry() public {
        vm.warp(auction.expiresAt());

        vm.prank(buyer1);
        vm.expectRevert(DutchAuction.AuctionExpired.selector);
        auction.buy{value: 10 ether}();
    }

    function testRemainingTimeReturnsZeroAfterExpiry() public {
        vm.warp(auction.expiresAt() + 1);

        assertEq(auction.getRemainingTime(), 0);
    }
}
