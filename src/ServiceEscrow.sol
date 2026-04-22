// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ServiceEscrow {
    error NotBuyer();
    error NotSeller();
    error NotArbiter();
    error InvalidSeller();
    error InvalidArbiter();
    error NoMilestones();
    error ZeroMilestoneAmount();
    error FundingMismatch();
    error InvalidMilestoneId();
    error MilestoneAlreadyApproved();
    error MilestoneNotApproved();
    error MilestoneAlreadyReleased();
    error MilestoneAlreadyDisputed();
    error MilestoneNotDisputed();
    error MilestoneAlreadyResolved();
    error TransferFailed();

    struct Milestone {
        uint256 amount;
        bool approved;
        bool disputed;
        bool resolved;
        bool released;
        bool refunded;
    }

    address public immutable buyer;
    address public immutable seller;
    address public immutable arbiter;
    uint256 public immutable totalFunded;

    uint256 public totalReleased;
    uint256 public totalRefunded;

    Milestone[] private milestones;

    event MilestoneApproved(uint256 indexed milestoneId, uint256 amount);
    event MilestoneClaimed(uint256 indexed milestoneId, uint256 amount);
    event DisputeOpened(uint256 indexed milestoneId);
    event DisputeResolved(uint256 indexed milestoneId, bool releasedToSeller, uint256 amount);

    modifier onlyBuyer() {
        if (msg.sender != buyer) revert NotBuyer();
        _;
    }

    modifier onlySeller() {
        if (msg.sender != seller) revert NotSeller();
        _;
    }

    modifier onlyArbiter() {
        if (msg.sender != arbiter) revert NotArbiter();
        _;
    }

    constructor(address _seller, address _arbiter, uint256[] memory _milestoneAmounts) payable {
        if (_seller == address(0)) revert InvalidSeller();
        if (_arbiter == address(0)) revert InvalidArbiter();
        if (_milestoneAmounts.length == 0) revert NoMilestones();

        uint256 sum;

        for (uint256 i = 0; i < _milestoneAmounts.length; i++) {
            uint256 amount = _milestoneAmounts[i];
            if (amount == 0) revert ZeroMilestoneAmount();

            milestones.push(
                Milestone({
                    amount: amount, approved: false, disputed: false, resolved: false, released: false, refunded: false
                })
            );

            sum += amount;
        }

        if (msg.value != sum) revert FundingMismatch();

        buyer = msg.sender;
        seller = _seller;
        arbiter = _arbiter;
        totalFunded = sum;
    }

    function approveMilestone(uint256 milestoneId) external onlyBuyer {
        if (milestoneId >= milestones.length) revert InvalidMilestoneId();

        Milestone storage milestone = milestones[milestoneId];

        if (milestone.approved) revert MilestoneAlreadyApproved();
        if (milestone.disputed) revert MilestoneAlreadyDisputed();
        if (milestone.resolved) revert MilestoneAlreadyResolved();
        if (milestone.released) revert MilestoneAlreadyReleased();

        milestone.approved = true;

        emit MilestoneApproved(milestoneId, milestone.amount);
    }

    function claimMilestone(uint256 milestoneId) external onlySeller {
        if (milestoneId >= milestones.length) revert InvalidMilestoneId();

        Milestone storage milestone = milestones[milestoneId];

        if (!milestone.approved) revert MilestoneNotApproved();
        if (milestone.disputed) revert MilestoneAlreadyDisputed();
        if (milestone.resolved) revert MilestoneAlreadyResolved();
        if (milestone.released) revert MilestoneAlreadyReleased();

        milestone.released = true;
        totalReleased += milestone.amount;

        (bool success,) = payable(seller).call{value: milestone.amount}("");
        if (!success) revert TransferFailed();

        emit MilestoneClaimed(milestoneId, milestone.amount);
    }

    function openDispute(uint256 milestoneId) external onlyBuyer {
        if (milestoneId >= milestones.length) revert InvalidMilestoneId();

        Milestone storage milestone = milestones[milestoneId];

        if (milestone.released) revert MilestoneAlreadyReleased();
        if (milestone.resolved) revert MilestoneAlreadyResolved();
        if (milestone.disputed) revert MilestoneAlreadyDisputed();

        milestone.disputed = true;

        emit DisputeOpened(milestoneId);
    }

    function resolveDispute(uint256 milestoneId, bool releaseToSeller) external onlyArbiter {
        if (milestoneId >= milestones.length) revert InvalidMilestoneId();

        Milestone storage milestone = milestones[milestoneId];

        if (!milestone.disputed) revert MilestoneNotDisputed();
        if (milestone.resolved) revert MilestoneAlreadyResolved();

        milestone.resolved = true;

        address recipient = releaseToSeller ? seller : buyer;

        if (releaseToSeller) {
            milestone.released = true;
            totalReleased += milestone.amount;
        } else {
            milestone.refunded = true;
            totalRefunded += milestone.amount;
        }

        (bool success,) = payable(recipient).call{value: milestone.amount}("");
        if (!success) revert TransferFailed();

        emit DisputeResolved(milestoneId, releaseToSeller, milestone.amount);
    }

    function getMilestone(uint256 milestoneId)
        external
        view
        returns (uint256 amount, bool approved, bool disputed, bool resolved, bool released, bool refunded)
    {
        if (milestoneId >= milestones.length) revert InvalidMilestoneId();

        Milestone memory milestone = milestones[milestoneId];
        return (
            milestone.amount,
            milestone.approved,
            milestone.disputed,
            milestone.resolved,
            milestone.released,
            milestone.refunded
        );
    }

    function getMilestoneCount() external view returns (uint256) {
        return milestones.length;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
