// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";
import {Marketplace} from "../src/Marketplace.sol";

contract MarketplaceTest is Test {
    Marketplace public marketplace;

    address public seller = address(1);
    address public buyer = address(2);

    function setUp() public {
        marketplace = new Marketplace();

        vm.deal(seller, 1 ether);
        vm.deal(buyer, 10 ether);
    }

    function test_ListItem() public {
        vm.prank(seller);
        marketplace.listItem("Laptop", 1 ether);

        (uint256 id, address itemSeller, string memory name, uint256 price, bool sold) = marketplace.getItem(1);

        assertEq(id, 1);
        assertEq(itemSeller, seller);
        assertEq(name, "Laptop");
        assertEq(price, 1 ether);
        assertEq(sold, false);
    }

    function test_BuyItem() public {
        vm.prank(seller);
        marketplace.listItem("Phone", 2 ether);

        uint256 sellerBalanceBefore = seller.balance;

        vm.prank(buyer);
        marketplace.buyItem{value: 2 ether}(1);

        uint256 sellerBalanceAfter = seller.balance;

        (,,,, bool sold) = marketplace.getItem(1);

        assertEq(sold, true);
        assertEq(sellerBalanceAfter - sellerBalanceBefore, 2 ether);
    }

    function test_CannotBuyOwnItem() public {
        vm.prank(seller);
        marketplace.listItem("Tablet", 1 ether);

        vm.prank(seller);
        vm.expectRevert(bytes("Seller tidak bisa membeli item sendiri"));
        marketplace.buyItem{value: 1 ether}(1);
    }

    function test_CannotBuyWithWrongETH() public {
        vm.prank(seller);
        marketplace.listItem("Mouse", 1 ether);

        vm.prank(buyer);
        vm.expectRevert(bytes("Jumlah ETH salah"));
        marketplace.buyItem{value: 0.5 ether}(1);
    }

    function test_CannotBuySoldItem() public {
        vm.prank(seller);
        marketplace.listItem("Keyboard", 1 ether);

        vm.prank(buyer);
        marketplace.buyItem{value: 1 ether}(1);

        vm.deal(address(3), 10 ether);
        vm.prank(address(3));
        vm.expectRevert(bytes("Item sudah terjual"));
        marketplace.buyItem{value: 1 ether}(1);
    }
}
