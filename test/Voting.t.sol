// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";
import {Voting} from "../src/Voting.sol";

contract VotingTest is Test {
    Voting public voting;

    address public owner = address(this);
    address public user1 = address(1);
    address public user2 = address(2);

    function setUp() public {
        voting = new Voting();
    }

    function test_CreateProposal() public {
        voting.createProposal("Tambah fitur staking");

        (string memory description, uint256 yesVotes, uint256 noVotes, bool finalized) = voting.getProposal(1);

        assertEq(description, "Tambah fitur staking");
        assertEq(yesVotes, 0);
        assertEq(noVotes, 0);
        assertEq(finalized, false);
    }

    function test_VoteYesAndNo() public {
        voting.createProposal("Tambah fitur escrow");

        vm.prank(user1);
        voting.vote(1, true);

        vm.prank(user2);
        voting.vote(1, false);

        (, uint256 yesVotes, uint256 noVotes,) = voting.getProposal(1);

        assertEq(yesVotes, 1);
        assertEq(noVotes, 1);
    }

    function test_CannotVoteTwice() public {
        voting.createProposal("Tambah fitur token");

        vm.prank(user1);
        voting.vote(1, true);

        vm.prank(user1);
        vm.expectRevert(bytes("Sudah vote"));
        voting.vote(1, false);
    }

    function test_FinalizeProposal() public {
        voting.createProposal("Tambah fitur DAO");
        voting.finalizeProposal(1);

        (,,, bool finalized) = voting.getProposal(1);
        assertEq(finalized, true);
    }

    function test_NonOwnerCannotCreateProposal() public {
        vm.prank(user1);
        vm.expectRevert(bytes("Hanya owner yang bisa buat proposal"));
        voting.createProposal("Proposal palsu");
    }

    function test_CannotVoteAfterFinalized() public {
        voting.createProposal("Tambah fitur voting");
        voting.finalizeProposal(1);

        vm.prank(user1);
        vm.expectRevert(bytes("Proposal sudah difinalisasi"));
        voting.vote(1, true);
    }
}
