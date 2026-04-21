// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MultiSigTreasuryAdvanced} from "../src/MultiSigTreasuryAdvanced.sol";

contract TreasuryReceiver {
    uint256 public number;
    uint256 public totalReceived;

    function setNumber(uint256 newNumber) external payable {
        number = newNumber;
        totalReceived += msg.value;
    }

    receive() external payable {
        totalReceived += msg.value;
    }
}

contract MultiSigTreasuryAdvancedTest is Test {
    MultiSigTreasuryAdvanced treasury;
    TreasuryReceiver receiver;

    address owner1 = address(0x1);
    address owner2 = address(0x2);
    address owner3 = address(0x3);
    address outsider = address(0x99);
    address recipient = address(0xBEEF);

    uint256 constant REQUIRED_CONFIRMATIONS = 2;

    function setUp() public {
        address[] memory _owners = new address[](3);
        _owners[0] = owner1;
        _owners[1] = owner2;
        _owners[2] = owner3;

        treasury = new MultiSigTreasuryAdvanced(_owners, REQUIRED_CONFIRMATIONS);
        receiver = new TreasuryReceiver();

        vm.deal(address(this), 20 ether);

        (bool success,) = address(treasury).call{value: 10 ether}("");
        assertTrue(success);
    }

    function testConstructorSetsInitialValues() public view {
        assertEq(treasury.requiredConfirmations(), REQUIRED_CONFIRMATIONS);
        assertTrue(treasury.isOwner(owner1));
        assertTrue(treasury.isOwner(owner2));
        assertTrue(treasury.isOwner(owner3));
        assertEq(treasury.getOwners().length, 3);
        assertEq(treasury.getTreasuryBalance(), 10 ether);
    }

    function testConstructorRevertsIfDuplicateOwner() public {
        address[] memory _owners = new address[](2);
        _owners[0] = owner1;
        _owners[1] = owner1;

        vm.expectRevert(MultiSigTreasuryAdvanced.DuplicateOwner.selector);
        new MultiSigTreasuryAdvanced(_owners, 2);
    }

    function testOnlyOwnerCanSubmitTransaction() public {
        vm.prank(outsider);
        vm.expectRevert(MultiSigTreasuryAdvanced.NotOwner.selector);
        treasury.submitTransaction(recipient, 1 ether, "");
    }

    function testSubmitTransactionStoresTransaction() public {
        vm.prank(owner1);
        treasury.submitTransaction(recipient, 1 ether, "");

        assertEq(treasury.getTransactionCount(), 1);

        (address txRecipient, uint256 amount, bytes memory data, uint256 confirmations, bool executed) =
            treasury.getTransaction(0);

        assertEq(txRecipient, recipient);
        assertEq(amount, 1 ether);
        assertEq(data.length, 0);
        assertEq(confirmations, 0);
        assertFalse(executed);
    }

    function testConfirmTransactionTracksApprovals() public {
        vm.prank(owner1);
        treasury.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        treasury.confirmTransaction(0);

        (,,, uint256 confirmations,) = treasury.getTransaction(0);

        assertEq(confirmations, 1);
        assertTrue(treasury.hasConfirmed(0, owner1));
    }

    function testCannotConfirmTwice() public {
        vm.prank(owner1);
        treasury.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        treasury.confirmTransaction(0);

        vm.prank(owner1);
        vm.expectRevert(MultiSigTreasuryAdvanced.AlreadyConfirmed.selector);
        treasury.confirmTransaction(0);
    }

    function testRevokeConfirmationWorks() public {
        vm.prank(owner1);
        treasury.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        treasury.confirmTransaction(0);

        vm.prank(owner1);
        treasury.revokeConfirmation(0);

        (,,, uint256 confirmations,) = treasury.getTransaction(0);

        assertEq(confirmations, 0);
        assertFalse(treasury.hasConfirmed(0, owner1));
    }

    function testExecuteTransactionTransfersEthAfterEnoughConfirmations() public {
        vm.prank(owner1);
        treasury.submitTransaction(recipient, 3 ether, "");

        vm.prank(owner1);
        treasury.confirmTransaction(0);

        vm.prank(owner2);
        treasury.confirmTransaction(0);

        uint256 recipientBalanceBefore = recipient.balance;

        vm.prank(owner3);
        treasury.executeTransaction(0);

        (,,, uint256 confirmations, bool executed) = treasury.getTransaction(0);

        assertEq(confirmations, 2);
        assertTrue(executed);
        assertEq(recipient.balance, recipientBalanceBefore + 3 ether);
        assertEq(treasury.getTreasuryBalance(), 7 ether);
    }

    function testExecuteTransactionCanCallContractWithData() public {
        bytes memory data = abi.encodeWithSignature("setNumber(uint256)", 42);

        vm.prank(owner1);
        treasury.submitTransaction(address(receiver), 2 ether, data);

        vm.prank(owner1);
        treasury.confirmTransaction(0);

        vm.prank(owner2);
        treasury.confirmTransaction(0);

        vm.prank(owner3);
        treasury.executeTransaction(0);

        assertEq(receiver.number(), 42);
        assertEq(receiver.totalReceived(), 2 ether);
        assertEq(treasury.getTreasuryBalance(), 8 ether);
    }

    function testExecuteRevertsWithoutEnoughConfirmations() public {
        vm.prank(owner1);
        treasury.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        treasury.confirmTransaction(0);

        vm.prank(owner2);
        vm.expectRevert(MultiSigTreasuryAdvanced.NotEnoughConfirmations.selector);
        treasury.executeTransaction(0);
    }

    function testOnlyOwnerCanExecuteTransaction() public {
        vm.prank(owner1);
        treasury.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        treasury.confirmTransaction(0);

        vm.prank(owner2);
        treasury.confirmTransaction(0);

        vm.prank(outsider);
        vm.expectRevert(MultiSigTreasuryAdvanced.NotOwner.selector);
        treasury.executeTransaction(0);
    }

    function testCannotExecuteTransactionTwice() public {
        vm.prank(owner1);
        treasury.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        treasury.confirmTransaction(0);

        vm.prank(owner2);
        treasury.confirmTransaction(0);

        vm.prank(owner3);
        treasury.executeTransaction(0);

        vm.prank(owner1);
        vm.expectRevert(MultiSigTreasuryAdvanced.AlreadyExecuted.selector);
        treasury.executeTransaction(0);
    }
}
