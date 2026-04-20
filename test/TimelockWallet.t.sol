// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";
import {TimelockWallet} from "../src/TimelockWallet.sol";

contract TimelockWalletTest is Test {
    TimelockWallet public wallet;

    address public owner = address(1);
    address public otherUser = address(2);

    uint256 public unlockAt;

    function setUp() public {
        unlockAt = block.timestamp + 100;

        vm.deal(owner, 10 ether);

        vm.prank(owner);
        wallet = new TimelockWallet{value: 5 ether}(unlockAt);
    }

    function test_InitialBalance() public view {
        assertEq(wallet.getBalance(), 5 ether);
    }

    function test_CannotWithdrawBeforeUnlock() public {
        vm.prank(owner);
        vm.expectRevert(bytes("Dana masih terkunci"));
        wallet.withdraw();
    }

    function test_OwnerCanWithdrawAfterUnlock() public {
        vm.warp(unlockAt);

        uint256 ownerBalanceBefore = owner.balance;

        vm.prank(owner);
        wallet.withdraw();

        uint256 ownerBalanceAfter = owner.balance;

        assertEq(ownerBalanceAfter - ownerBalanceBefore, 5 ether);
        assertEq(wallet.getBalance(), 0);
    }

    function test_NonOwnerCannotWithdraw() public {
        vm.warp(unlockAt);

        vm.prank(otherUser);
        vm.expectRevert(bytes("Hanya owner yang bisa withdraw"));
        wallet.withdraw();
    }

    function test_CanReceiveMoreETH() public {
        vm.deal(otherUser, 2 ether);

        vm.prank(otherUser);
        (bool success,) = address(wallet).call{value: 1 ether}("");
        require(success, "Deposit gagal");

        assertEq(wallet.getBalance(), 6 ether);
    }
}
