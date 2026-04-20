// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";
import {MyToken} from "../src/MyToken.sol";

contract MyTokenTest is Test {
    MyToken public token;
    address public owner = address(this);
    address public user1 = address(1);
    address public user2 = address(2);

    function setUp() public {
        token = new MyToken(1000 ether);
    }

    function test_InitialSupplyAssignedToOwner() public {
        assertEq(token.balanceOf(owner), 1000 ether);
        assertEq(token.totalSupply(), 1000 ether);
    }

    function test_Transfer() public {
        token.transfer(user1, 100 ether);

        assertEq(token.balanceOf(user1), 100 ether);
        assertEq(token.balanceOf(owner), 900 ether);
    }

    function test_OwnerCanMint() public {
        token.mint(user2, 50 ether);

        assertEq(token.balanceOf(user2), 50 ether);
        assertEq(token.totalSupply(), 1050 ether);
    }

    function test_NonOwnerCannotMint() public {
        vm.prank(user1);
        vm.expectRevert();
        token.mint(user2, 50 ether);
    }
}
