// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {GovernanceTokenSnapshot, GovernanceSnapshotVoting} from "../src/GovernanceSnapshotVoting.sol";

contract GovernanceSnapshotVotingTest is Test {
    GovernanceTokenSnapshot token;
    GovernanceSnapshotVoting voting;

    address owner = address(this);
    address user1 = address(0x1);
    address user2 = address(0x2);
    address user3 = address(0x3);
    address outsider = address(0x99);

    uint256 constant QUORUM = 100 ether;
    uint256 constant VOTING_DURATION = 1 days;

    function setUp() public {
        token = new GovernanceTokenSnapshot("Governance Token", "GOV");
        voting = new GovernanceSnapshotVoting(address(token), QUORUM);

        token.mint(user1, 100 ether);
        token.mint(user2, 50 ether);
        token.mint(user3, 20 ether);
    }

    function testConstructorSetsInitialValues() public view {
        assertEq(voting.owner(), owner);
        assertEq(address(voting.token()), address(token));
        assertEq(voting.quorum(), QUORUM);
    }

    function testCreateProposalStoresSnapshotAndData() public {
        voting.createProposal("Treasury upgrade", VOTING_DURATION);

        assertEq(voting.getProposalCount(), 1);

        GovernanceSnapshotVoting.Proposal memory proposal = voting.getProposal(0);
        assertEq(proposal.snapshotId, 1);
        assertEq(proposal.forVotes, 0);
        assertEq(proposal.againstVotes, 0);
        assertFalse(proposal.finalized);
        assertFalse(proposal.passed);
        assertEq(proposal.deadline, block.timestamp + VOTING_DURATION);
    }

    function testVoteUsesSnapshotBalanceEvenAfterTransfer() public {
        voting.createProposal("Treasury upgrade", VOTING_DURATION);

        vm.prank(user1);
        token.transfer(outsider, 60 ether);

        vm.prank(user1);
        voting.vote(0, true);

        GovernanceSnapshotVoting.Proposal memory proposal = voting.getProposal(0);
        assertEq(proposal.forVotes, 100 ether);
    }

    function testVoteRevertsIfNoVotingPowerAtSnapshot() public {
        voting.createProposal("Treasury upgrade", VOTING_DURATION);

        vm.prank(outsider);
        vm.expectRevert(GovernanceSnapshotVoting.GovNoVotingPower.selector);
        voting.vote(0, true);
    }

    function testCannotVoteTwice() public {
        voting.createProposal("Treasury upgrade", VOTING_DURATION);

        vm.prank(user1);
        voting.vote(0, true);

        vm.prank(user1);
        vm.expectRevert(GovernanceSnapshotVoting.GovAlreadyVoted.selector);
        voting.vote(0, true);
    }

    function testVoteRevertsAfterDeadline() public {
        voting.createProposal("Treasury upgrade", VOTING_DURATION);

        vm.warp(block.timestamp + VOTING_DURATION);

        vm.prank(user1);
        vm.expectRevert(GovernanceSnapshotVoting.GovProposalEnded.selector);
        voting.vote(0, true);
    }

    function testFinalizeMarksProposalPassedWhenQuorumReachedAndForVotesHigher() public {
        voting.createProposal("Treasury upgrade", VOTING_DURATION);

        vm.prank(user1);
        voting.vote(0, true);

        vm.prank(user2);
        voting.vote(0, true);

        vm.warp(block.timestamp + VOTING_DURATION + 1);

        voting.finalizeProposal(0);

        GovernanceSnapshotVoting.Proposal memory proposal = voting.getProposal(0);
        assertTrue(proposal.finalized);
        assertTrue(proposal.passed);
        assertEq(proposal.forVotes, 150 ether);
        assertEq(proposal.againstVotes, 0);
    }

    function testFinalizeMarksProposalRejectedWhenAgainstVotesWin() public {
        voting.createProposal("Treasury upgrade", VOTING_DURATION);

        vm.prank(user1);
        voting.vote(0, false);

        vm.prank(user2);
        voting.vote(0, false);

        vm.warp(block.timestamp + VOTING_DURATION + 1);

        voting.finalizeProposal(0);

        GovernanceSnapshotVoting.Proposal memory proposal = voting.getProposal(0);
        assertTrue(proposal.finalized);
        assertFalse(proposal.passed);
        assertEq(proposal.forVotes, 0);
        assertEq(proposal.againstVotes, 150 ether);
    }

    function testFinalizeMarksProposalRejectedWhenQuorumNotReached() public {
        voting.createProposal("Treasury upgrade", VOTING_DURATION);

        vm.prank(user3);
        voting.vote(0, true);

        vm.warp(block.timestamp + VOTING_DURATION + 1);

        voting.finalizeProposal(0);

        GovernanceSnapshotVoting.Proposal memory proposal = voting.getProposal(0);
        assertTrue(proposal.finalized);
        assertFalse(proposal.passed);
        assertEq(proposal.forVotes, 20 ether);
        assertEq(proposal.againstVotes, 0);
    }

    function testOnlyOwnerCanCreateOrFinalizeProposal() public {
        vm.prank(user1);
        vm.expectRevert(GovernanceSnapshotVoting.GovNotOwner.selector);
        voting.createProposal("Treasury upgrade", VOTING_DURATION);

        voting.createProposal("Treasury upgrade", VOTING_DURATION);

        vm.warp(block.timestamp + VOTING_DURATION + 1);

        vm.prank(user1);
        vm.expectRevert(GovernanceSnapshotVoting.GovNotOwner.selector);
        voting.finalizeProposal(0);
    }
}
