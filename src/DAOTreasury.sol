// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract DAOTreasury {
    error NotMember();
    error InvalidMember();
    error DuplicateMember();
    error InvalidQuorum();
    error InvalidProposalId();
    error InvalidRecipient();
    error InvalidAmount();
    error AlreadyApproved();
    error ProposalAlreadyExecuted();
    error NotEnoughApprovals();
    error InsufficientTreasuryBalance();
    error TransferFailed();

    struct Proposal {
        address recipient;
        uint256 amount;
        uint256 approvals;
        bool executed;
    }

    address public immutable owner;
    uint256 public immutable quorum;

    mapping(address => bool) public isMember;
    mapping(uint256 => mapping(address => bool)) public hasApproved;

    Proposal[] private proposals;
    address[] private members;

    event Deposit(address indexed sender, uint256 amount);
    event ProposalCreated(uint256 indexed proposalId, address indexed recipient, uint256 amount);
    event ProposalApproved(uint256 indexed proposalId, address indexed member);
    event ProposalExecuted(uint256 indexed proposalId, address indexed recipient, uint256 amount);

    modifier onlyMember() {
        if (!isMember[msg.sender]) revert NotMember();
        _;
    }

    constructor(address[] memory _members, uint256 _quorum) {
        if (_members.length == 0) revert InvalidMember();
        if (_quorum == 0 || _quorum > _members.length) revert InvalidQuorum();

        owner = msg.sender;
        quorum = _quorum;

        for (uint256 i = 0; i < _members.length; i++) {
            address member = _members[i];

            if (member == address(0)) revert InvalidMember();
            if (isMember[member]) revert DuplicateMember();

            isMember[member] = true;
            members.push(member);
        }
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submitProposal(address recipient, uint256 amount) external onlyMember returns (uint256 proposalId) {
        if (recipient == address(0)) revert InvalidRecipient();
        if (amount == 0) revert InvalidAmount();

        proposalId = proposals.length;
        proposals.push(Proposal({recipient: recipient, amount: amount, approvals: 0, executed: false}));

        emit ProposalCreated(proposalId, recipient, amount);
    }

    function approveProposal(uint256 proposalId) external onlyMember {
        if (proposalId >= proposals.length) revert InvalidProposalId();

        Proposal storage proposal = proposals[proposalId];

        if (proposal.executed) revert ProposalAlreadyExecuted();
        if (hasApproved[proposalId][msg.sender]) revert AlreadyApproved();

        hasApproved[proposalId][msg.sender] = true;
        proposal.approvals += 1;

        emit ProposalApproved(proposalId, msg.sender);
    }

    function executeProposal(uint256 proposalId) external onlyMember {
        if (proposalId >= proposals.length) revert InvalidProposalId();

        Proposal storage proposal = proposals[proposalId];

        if (proposal.executed) revert ProposalAlreadyExecuted();
        if (proposal.approvals < quorum) revert NotEnoughApprovals();
        if (address(this).balance < proposal.amount) revert InsufficientTreasuryBalance();

        proposal.executed = true;

        (bool success,) = payable(proposal.recipient).call{value: proposal.amount}("");
        if (!success) revert TransferFailed();

        emit ProposalExecuted(proposalId, proposal.recipient, proposal.amount);
    }

    function getProposal(uint256 proposalId) external view returns (Proposal memory) {
        if (proposalId >= proposals.length) revert InvalidProposalId();
        return proposals[proposalId];
    }

    function getProposalCount() external view returns (uint256) {
        return proposals.length;
    }

    function getMembers() external view returns (address[] memory) {
        return members;
    }

    function getTreasuryBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
