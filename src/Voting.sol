// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.33;

contract Voting {
    address public owner;
    uint256 public proposalCount;

    struct Proposal {
        string description;
        uint256 yesVotes;
        uint256 noVotes;
        bool finalized;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event ProposalCreated(uint256 indexed proposalId, string description);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support);
    event ProposalFinalized(uint256 indexed proposalId);

    constructor() {
        owner = msg.sender;
    }

    function createProposal(string memory description) public {
        require(msg.sender == owner, "Hanya owner yang bisa buat proposal");
        require(bytes(description).length > 0, "Deskripsi tidak boleh kosong");

        proposalCount++;

        proposals[proposalCount] = Proposal({description: description, yesVotes: 0, noVotes: 0, finalized: false});

        emit ProposalCreated(proposalCount, description);
    }

    function vote(uint256 proposalId, bool support) public {
        require(proposalId > 0 && proposalId <= proposalCount, "Proposal tidak valid");
        require(!proposals[proposalId].finalized, "Proposal sudah difinalisasi");
        require(!hasVoted[proposalId][msg.sender], "Sudah vote");

        hasVoted[proposalId][msg.sender] = true;

        if (support) {
            proposals[proposalId].yesVotes++;
        } else {
            proposals[proposalId].noVotes++;
        }

        emit Voted(proposalId, msg.sender, support);
    }

    function finalizeProposal(uint256 proposalId) public {
        require(msg.sender == owner, "Hanya owner yang bisa finalisasi");
        require(proposalId > 0 && proposalId <= proposalCount, "Proposal tidak valid");
        require(!proposals[proposalId].finalized, "Proposal sudah difinalisasi");

        proposals[proposalId].finalized = true;

        emit ProposalFinalized(proposalId);
    }

    function getProposal(uint256 proposalId)
        public
        view
        returns (string memory description, uint256 yesVotes, uint256 noVotes, bool finalized)
    {
        Proposal memory proposal = proposals[proposalId];
        return (proposal.description, proposal.yesVotes, proposal.noVotes, proposal.finalized);
    }
}
