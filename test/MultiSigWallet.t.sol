// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";

contract MultiSigWalletTest is Test {
    MultiSigWallet public wallet;

    address public owner1 = address(1);
    address public owner2 = address(2);
    address public owner3 = address(3);
    address public recipient = address(99);

    function setUp() public {
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        vm.prank(owner1);
        wallet = new MultiSigWallet(owners, 2);

        vm.deal(owner1, 10 ether);
        vm.prank(owner1);
        (bool success,) = address(wallet).call{value: 5 ether}("");
        require(success, "Funding wallet gagal");
    }

    function test_SubmitTransaction() public {
        vm.prank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");

        assertEq(wallet.getTransactionCount(), 1);

        (address to, uint256 value,, bool executed, uint256 numConfirmations) = wallet.getTransaction(0);

        assertEq(to, recipient);
        assertEq(value, 1 ether);
        assertEq(executed, false);
        assertEq(numConfirmations, 0);
    }

    function test_ConfirmTransaction() public {
        vm.prank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        (,,,, uint256 numConfirmations) = wallet.getTransaction(0);
        assertEq(numConfirmations, 1);
    }

    function test_CannotConfirmTwice() public {
        vm.prank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner1);
        vm.expectRevert(bytes("Sudah konfirmasi"));
        wallet.confirmTransaction(0);
    }

    function test_ExecuteTransaction() public {
        vm.prank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner2);
        wallet.confirmTransaction(0);

        uint256 balanceBefore = recipient.balance;

        vm.prank(owner1);
        wallet.executeTransaction(0);

        uint256 balanceAfter = recipient.balance;

        (,,, bool executed, uint256 numConfirmations) = wallet.getTransaction(0);

        assertEq(balanceAfter - balanceBefore, 1 ether);
        assertEq(executed, true);
        assertEq(numConfirmations, 2);
    }

    function test_CannotExecuteWithoutEnoughConfirmations() public {
        vm.prank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner1);
        vm.expectRevert(bytes("Konfirmasi belum cukup"));
        wallet.executeTransaction(0);
    }

    function test_NonOwnerCannotSubmitTransaction() public {
        vm.prank(address(50));
        vm.expectRevert(bytes("Bukan owner"));
        wallet.submitTransaction(recipient, 1 ether, "");
    }
}
