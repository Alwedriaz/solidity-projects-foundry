// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {PaymentSplitter} from "../src/PaymentSplitter.sol";

contract PaymentSplitterTest is Test {
    PaymentSplitter splitter;

    address payable alice = payable(address(0x1));
    address payable bob = payable(address(0x2));
    address payable carol = payable(address(0x3));
    address outsider = address(0x99);

    uint256 constant ALICE_SHARES = 50;
    uint256 constant BOB_SHARES = 30;
    uint256 constant CAROL_SHARES = 20;

    function setUp() public {
        address[] memory payees = new address[](3);
        uint256[] memory shareValues = new uint256[](3);

        payees[0] = alice;
        payees[1] = bob;
        payees[2] = carol;

        shareValues[0] = ALICE_SHARES;
        shareValues[1] = BOB_SHARES;
        shareValues[2] = CAROL_SHARES;

        splitter = new PaymentSplitter(payees, shareValues);

        vm.deal(address(this), 100 ether);
        vm.deal(alice, 0);
        vm.deal(bob, 0);
        vm.deal(carol, 0);
        vm.deal(outsider, 0);
    }

    function testConstructorSetsInitialValues() public view {
        assertEq(splitter.totalShares(), 100);
        assertEq(splitter.shares(alice), ALICE_SHARES);
        assertEq(splitter.shares(bob), BOB_SHARES);
        assertEq(splitter.shares(carol), CAROL_SHARES);
        assertTrue(splitter.isPayee(alice));
        assertTrue(splitter.isPayee(bob));
        assertTrue(splitter.isPayee(carol));
        assertEq(splitter.getPayees().length, 3);
    }

    function testConstructorRevertsIfLengthsMismatch() public {
        address[] memory payees = new address[](2);
        uint256[] memory shareValues = new uint256[](1);

        payees[0] = alice;
        payees[1] = bob;
        shareValues[0] = 100;

        vm.expectRevert(PaymentSplitter.LengthMismatch.selector);
        new PaymentSplitter(payees, shareValues);
    }

    function testConstructorRevertsIfDuplicatePayee() public {
        address[] memory payees = new address[](2);
        uint256[] memory shareValues = new uint256[](2);

        payees[0] = alice;
        payees[1] = alice;

        shareValues[0] = 60;
        shareValues[1] = 40;

        vm.expectRevert(PaymentSplitter.DuplicatePayee.selector);
        new PaymentSplitter(payees, shareValues);
    }

    function testReleaseRevertsForNonPayee() public {
        vm.prank(outsider);
        vm.expectRevert(PaymentSplitter.NotPayee.selector);
        splitter.release();
    }

    function testReleaseRevertsWhenNoPaymentDue() public {
        vm.prank(alice);
        vm.expectRevert(PaymentSplitter.NoPaymentDue.selector);
        splitter.release();
    }

    function testReleaseDistributesFundsCorrectly() public {
        fundSplitter(10 ether);

        assertEq(splitter.releasable(alice), 5 ether);
        assertEq(splitter.releasable(bob), 3 ether);
        assertEq(splitter.releasable(carol), 2 ether);

        vm.prank(alice);
        splitter.release();

        vm.prank(bob);
        splitter.release();

        vm.prank(carol);
        splitter.release();

        assertEq(alice.balance, 5 ether);
        assertEq(bob.balance, 3 ether);
        assertEq(carol.balance, 2 ether);

        assertEq(address(splitter).balance, 0);
        assertEq(splitter.totalReleased(), 10 ether);
    }

    function testMultipleDepositsKeepAccountingCorrect() public {
        fundSplitter(10 ether);

        vm.prank(alice);
        splitter.release();

        assertEq(alice.balance, 5 ether);
        assertEq(splitter.releasable(alice), 0);

        fundSplitter(10 ether);

        assertEq(splitter.releasable(alice), 5 ether);

        vm.prank(alice);
        splitter.release();

        assertEq(alice.balance, 10 ether);
    }

    function testContractBalanceUpdatesAfterFunding() public {
        fundSplitter(4 ether);
        assertEq(splitter.getContractBalance(), 4 ether);
    }

    function fundSplitter(uint256 amount) internal {
        (bool success,) = address(splitter).call{value: amount}("");
        assertTrue(success);
    }
}
