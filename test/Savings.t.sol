// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Savings} from "../src/Savings.sol";

contract SavingsTest is Test {
    Savings public savings;
    address public user1 = address(1);

    function setUp() public {
        savings = new Savings();
        vm.deal(user1, 10 ether);
    }

    function test_Deposit() public {
        vm.prank(user1);
        savings.deposit{value: 1 ether}();

        assertEq(savings.getBalance(user1), 1 ether);
    }

    function test_Withdraw() public {
        vm.startPrank(user1);

        savings.deposit{value: 2 ether}();
        savings.withdraw(1 ether);

        vm.stopPrank();

        assertEq(savings.getBalance(user1), 1 ether);
    }

    function test_WithdrawFailsIfBalanceNotEnough() public {
        vm.prank(user1);
        vm.expectRevert("Saldo tidak cukup");
        savings.withdraw(1 ether);
    }

    function test_DepositFailsIfZero() public {
        vm.prank(user1);
        vm.expectRevert("Jumlah harus lebih dari 0");
        savings.deposit{value: 0}();
    }
}
