// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GovernanceTokenSnapshot {
    error TokenNotOwner();
    error TokenInvalidAddress();
    error TokenZeroAmount();
    error TokenInsufficientBalance();

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    address public immutable owner;
    uint256 public totalSupply;
    uint256 public currentSnapshotId;

    mapping(address => uint256) public balanceOf;
    mapping(address => bool) private holderExists;
    address[] private holders;

    mapping(uint256 => mapping(address => uint256)) private snapshotBalances;
    mapping(uint256 => uint256) private snapshotTotalSupply;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Mint(address indexed to, uint256 amount);
    event SnapshotCreated(uint256 indexed snapshotId);

    modifier onlyOwner() {
        if (msg.sender != owner) revert TokenNotOwner();
        _;
    }

    constructor(string memory _name, string memory _symbol) {
        owner = msg.sender;
        name = _name;
        symbol = _symbol;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert TokenInvalidAddress();
        if (amount == 0) revert TokenZeroAmount();

        balanceOf[to] += amount;
        totalSupply += amount;

        _addHolder(to);

        emit Mint(to, amount);
        emit Transfer(address(0), to, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert TokenInvalidAddress();
        if (amount == 0) revert TokenZeroAmount();
        if (balanceOf[msg.sender] < amount) revert TokenInsufficientBalance();

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        _addHolder(to);

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function snapshot() external returns (uint256 snapshotId) {
        snapshotId = currentSnapshotId + 1;
        currentSnapshotId = snapshotId;

        snapshotTotalSupply[snapshotId] = totalSupply;

        uint256 length = holders.length;
        for (uint256 i = 0; i < length; i++) {
            address holder = holders[i];
            snapshotBalances[snapshotId][holder] = balanceOf[holder];
        }

        emit SnapshotCreated(snapshotId);
    }

    function balanceOfAt(address account, uint256 snapshotId) external view returns (uint256) {
        return snapshotBalances[snapshotId][account];
    }

    function totalSupplyAt(uint256 snapshotId) external view returns (uint256) {
        return snapshotTotalSupply[snapshotId];
    }

    function getHolders() external view returns (address[] memory) {
        return holders;
    }

    function _addHolder(address account) internal {
        if (!holderExists[account] && balanceOf[account] > 0) {
            holderExists[account] = true;
            holders.push(account);
        }
    }
}

interface IGovernanceTokenSnapshot {
    function snapshot() external returns (uint256);
    function balanceOfAt(address account, uint256 snapshotId) external view returns (uint256);
    function totalSupplyAt(uint256 snapshotId) external view returns (uint256);
}

contract GovernanceSnapshotVoting {
    error GovNotOwner();
    error GovInvalidToken();
    error GovInvalidDuration();
    error GovInvalidQuorum();
    error GovInvalidProposalId();
    error GovProposalEnded();
    error GovAlreadyVoted();
    error GovNoVotingPower();
    error GovProposalAlreadyFinalized();
    error GovVotingStillActive();

    struct Proposal {
        string description;
        uint256 snapshotId;
        uint256 deadline;
        uint256 forVotes;
        uint256 againstVotes;
        bool finalized;
        bool passed;
    }

    address public immutable owner;
    IGovernanceTokenSnapshot public immutable token;
    uint256 public immutable quorum;

    Proposal[] private proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event ProposalCreated(uint256 indexed proposalId, uint256 indexed snapshotId, string description, uint256 deadline);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 votingPower);
    event ProposalFinalized(uint256 indexed proposalId, bool passed, uint256 forVotes, uint256 againstVotes);

    modifier onlyOwner() {
        if (msg.sender != owner) revert GovNotOwner();
        _;
    }

    constructor(address _token, uint256 _quorum) {
        if (_token == address(0)) revert GovInvalidToken();
        if (_quorum == 0) revert GovInvalidQuorum();

        owner = msg.sender;
        token = IGovernanceTokenSnapshot(_token);
        quorum = _quorum;
    }

    function createProposal(string memory description, uint256 duration)
        external
        onlyOwner
        returns (uint256 proposalId)
    {
        if (duration == 0) revert GovInvalidDuration();

        uint256 snapshotId = token.snapshot();
        proposalId = proposals.length;

        proposals.push(
            Proposal({
                description: description,
                snapshotId: snapshotId,
                deadline: block.timestamp + duration,
                forVotes: 0,
                againstVotes: 0,
                finalized: false,
                passed: false
            })
        );

        emit ProposalCreated(proposalId, snapshotId, description, block.timestamp + duration);
    }

    function vote(uint256 proposalId, bool support) external {
        if (proposalId >= proposals.length) revert GovInvalidProposalId();

        Proposal storage proposal = proposals[proposalId];

        if (proposal.finalized || block.timestamp >= proposal.deadline) {
            revert GovProposalEnded();
        }
        if (hasVoted[proposalId][msg.sender]) revert GovAlreadyVoted();

        uint256 votingPower = token.balanceOfAt(msg.sender, proposal.snapshotId);
        if (votingPower == 0) revert GovNoVotingPower();

        hasVoted[proposalId][msg.sender] = true;

        if (support) {
            proposal.forVotes += votingPower;
        } else {
            proposal.againstVotes += votingPower;
        }

        emit Voted(proposalId, msg.sender, support, votingPower);
    }

    function finalizeProposal(uint256 proposalId) external onlyOwner {
        if (proposalId >= proposals.length) revert GovInvalidProposalId();

        Proposal storage proposal = proposals[proposalId];

        if (proposal.finalized) revert GovProposalAlreadyFinalized();
        if (block.timestamp < proposal.deadline) revert GovVotingStillActive();

        proposal.finalized = true;

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        proposal.passed = totalVotes >= quorum && proposal.forVotes > proposal.againstVotes;

        emit ProposalFinalized(proposalId, proposal.passed, proposal.forVotes, proposal.againstVotes);
    }

    function getProposal(uint256 proposalId) external view returns (Proposal memory) {
        if (proposalId >= proposals.length) revert GovInvalidProposalId();
        return proposals[proposalId];
    }

    function getProposalCount() external view returns (uint256) {
        return proposals.length;
    }
}
