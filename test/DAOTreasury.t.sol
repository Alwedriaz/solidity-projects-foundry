// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DAOTreasury} from "../src/DAOTreasury.sol";

contract DAOTreasuryTest is Test {
    DAOTreasury treasury;

    address owner = address(this);
    address member1 = address(0x1);
    address member2 = address(0x2);
    address member3 = address(0x3);
    address outsider = address(0x99);
    address recipient = address(0xBEEF);

    uint256 constant QUORUM = 2;

    function setUp() public {
        address[] memory members = new address[](3);
        members[0] = member1;
        members[1] = member2;
        members[2] = member3;

        treasury = new DAOTreasury(members, QUORUM);

        vm.deal(address(this), 20 ether);
        vm.deal(member1, 1 ether);
        vm.deal(member2, 1 ether);
        vm.deal(member3, 1 ether);
        vm.deal(outsider, 1 ether);
    }

    function testConstructorSetsInitialValues() public view {
        assertEq(treasury.owner(), owner);
        assertEq(treasury.quorum(), QUORUM);
        assertTrue(treasury.isMember(member1));
        assertTrue(treasury.isMember(member2));
        assertTrue(treasury.isMember(member3));
        assertEq(treasury.getMembers().length, 3);
    }

    function testConstructorRevertsIfQuorumInvalid() public {
        address[] memory members = new address[](2);
        members[0] = member1;
        members[1] = member2;

        vm.expectRevert(DAOTreasury.InvalidQuorum.selector);
        new DAOTreasury(members, 0);
    }

    function testReceiveAddsTreasuryBalance() public {
        (bool success,) = address(treasury).call{value: 5 ether}("");
        assertTrue(success);
        assertEq(treasury.getTreasuryBalance(), 5 ether);
    }

    function testOnlyMemberCanSubmitProposal() public {
        vm.prank(outsider);
        vm.expectRevert(DAOTreasury.NotMember.selector);
        treasury.submitProposal(recipient, 1 ether);
    }

    function testSubmitProposalStoresProposal() public {
        vm.prank(member1);
        treasury.submitProposal(recipient, 2 ether);

        assertEq(treasury.getProposalCount(), 1);

        DAOTreasury.Proposal memory proposal = treasury.getProposal(0);
        assertEq(proposal.recipient, recipient);
        assertEq(proposal.amount, 2 ether);
        assertEq(proposal.approvals, 0);
        assertFalse(proposal.executed);
    }

    function testApproveProposalTracksApprovals() public {
        vm.prank(member1);
        treasury.submitProposal(recipient, 1 ether);

        vm.prank(member1);
        treasury.approveProposal(0);

        DAOTreasury.Proposal memory proposal = treasury.getProposal(0);
        assertEq(proposal.approvals, 1);
        assertTrue(treasury.hasApproved(0, member1));
    }

    function testCannotApproveTwice() public {
        vm.prank(member1);
        treasury.submitProposal(recipient, 1 ether);

        vm.prank(member1);
        treasury.approveProposal(0);

        vm.prank(member1);
        vm.expectRevert(DAOTreasury.AlreadyApproved.selector);
        treasury.approveProposal(0);
    }

    function testExecuteProposalTransfersFundsAfterQuorum() public {
        fundTreasury(10 ether);

        vm.prank(member1);
        treasury.submitProposal(recipient, 4 ether);

        vm.prank(member1);
        treasury.approveProposal(0);

        vm.prank(member2);
        treasury.approveProposal(0);

        uint256 recipientBalanceBefore = recipient.balance;

        vm.prank(member3);
        treasury.executeProposal(0);

        DAOTreasury.Proposal memory proposal = treasury.getProposal(0);

        assertTrue(proposal.executed);
        assertEq(recipient.balance, recipientBalanceBefore + 4 ether);
        assertEq(treasury.getTreasuryBalance(), 6 ether);
    }

    function testExecuteProposalRevertsWithoutEnoughApprovals() public {
        fundTreasury(10 ether);

        vm.prank(member1);
        treasury.submitProposal(recipient, 4 ether);

        vm.prank(member1);
        treasury.approveProposal(0);

        vm.prank(member2);
        vm.expectRevert(DAOTreasury.NotEnoughApprovals.selector);
        treasury.executeProposal(0);
    }

    function testOnlyMemberCanExecuteProposal() public {
        fundTreasury(10 ether);

        vm.prank(member1);
        treasury.submitProposal(recipient, 4 ether);

        vm.prank(member1);
        treasury.approveProposal(0);

        vm.prank(member2);
        treasury.approveProposal(0);

        vm.prank(outsider);
        vm.expectRevert(DAOTreasury.NotMember.selector);
        treasury.executeProposal(0);
    }

    function fundTreasury(uint256 amount) internal {
        (bool success,) = address(treasury).call{value: amount}("");
        assertTrue(success);
    }
}
