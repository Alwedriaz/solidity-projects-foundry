// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Escrow} from "../src/Escrow.sol";

contract EscrowTest is Test {
    Escrow public escrow;
    address public buyer = address(1);
    address public seller = address(2);

    function setUp() public {
        escrow = new Escrow(buyer, seller);
        vm.deal(buyer, 10 ether);
    }

    function test_Deposit() public {
        vm.prank(buyer);
        escrow.deposit{value: 1 ether}();

        assertEq(escrow.getContractBalance(), 1 ether);
    }

    function test_Release() public {
        vm.startPrank(buyer);

        escrow.deposit{value: 1 ether}();
        escrow.release();

        vm.stopPrank();

        assertEq(escrow.getContractBalance(), 0);
    }

    function test_DepositFailsIfNotBuyer() public {
        address notBuyer = address(3);
        vm.deal(notBuyer, 10 ether);

        vm.prank(notBuyer);
        vm.expectRevert(bytes("Hanya buyer yang bisa deposit"));
        escrow.deposit{value: 1 ether}();
    }
}
