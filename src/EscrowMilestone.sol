// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract EscrowMilestone {
    error NotBuyer();
    error NotSeller();
    error InvalidSeller();
    error NoMilestones();
    error ZeroMilestoneAmount();
    error FundingMismatch();
    error InvalidMilestoneId();
    error MilestoneAlreadyApproved();
    error MilestoneNotApproved();
    error MilestoneAlreadyReleased();
    error EscrowCancelled();
    error NothingToRefund();
    error TransferFailed();

    struct Milestone {
        uint256 amount;
        bool approved;
        bool released;
    }

    address public immutable buyer;
    address public immutable seller;
    uint256 public immutable totalFunded;

    bool public cancelled;
    uint256 public totalReleased;

    Milestone[] private milestones;

    event MilestoneApproved(uint256 indexed milestoneId, uint256 amount);
    event MilestoneReleased(uint256 indexed milestoneId, uint256 amount);
    event Refunded(address indexed buyer, uint256 amount);

    modifier onlyBuyer() {
        if (msg.sender != buyer) revert NotBuyer();
        _;
    }

    modifier onlySeller() {
        if (msg.sender != seller) revert NotSeller();
        _;
    }

    constructor(address _seller, uint256[] memory _milestoneAmounts) payable {
        if (_seller == address(0)) revert InvalidSeller();
        if (_milestoneAmounts.length == 0) revert NoMilestones();

        uint256 sum;

        for (uint256 i = 0; i < _milestoneAmounts.length; i++) {
            uint256 amount = _milestoneAmounts[i];
            if (amount == 0) revert ZeroMilestoneAmount();

            milestones.push(Milestone({amount: amount, approved: false, released: false}));

            sum += amount;
        }

        if (msg.value != sum) revert FundingMismatch();

        buyer = msg.sender;
        seller = _seller;
        totalFunded = sum;
    }

    function approveMilestone(uint256 milestoneId) external onlyBuyer {
        if (cancelled) revert EscrowCancelled();
        if (milestoneId >= milestones.length) revert InvalidMilestoneId();

        Milestone storage milestone = milestones[milestoneId];

        if (milestone.approved) revert MilestoneAlreadyApproved();
        if (milestone.released) revert MilestoneAlreadyReleased();

        milestone.approved = true;

        emit MilestoneApproved(milestoneId, milestone.amount);
    }

    function releaseMilestone(uint256 milestoneId) external onlySeller {
        if (milestoneId >= milestones.length) revert InvalidMilestoneId();

        Milestone storage milestone = milestones[milestoneId];

        if (!milestone.approved) revert MilestoneNotApproved();
        if (milestone.released) revert MilestoneAlreadyReleased();

        milestone.released = true;
        totalReleased += milestone.amount;

        (bool success,) = payable(seller).call{value: milestone.amount}("");
        if (!success) revert TransferFailed();

        emit MilestoneReleased(milestoneId, milestone.amount);
    }

    function cancelRemaining() external onlyBuyer {
        uint256 lockedApproved = _getLockedApprovedAmount();
        uint256 balance = address(this).balance;

        if (balance <= lockedApproved) revert NothingToRefund();

        cancelled = true;

        uint256 refundAmount = balance - lockedApproved;

        (bool success,) = payable(buyer).call{value: refundAmount}("");
        if (!success) revert TransferFailed();

        emit Refunded(buyer, refundAmount);
    }

    function getMilestone(uint256 milestoneId) external view returns (uint256 amount, bool approved, bool released) {
        if (milestoneId >= milestones.length) revert InvalidMilestoneId();

        Milestone memory milestone = milestones[milestoneId];
        return (milestone.amount, milestone.approved, milestone.released);
    }

    function getMilestoneCount() external view returns (uint256) {
        return milestones.length;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getLockedApprovedAmount() external view returns (uint256) {
        return _getLockedApprovedAmount();
    }

    function _getLockedApprovedAmount() internal view returns (uint256 locked) {
        uint256 length = milestones.length;

        for (uint256 i = 0; i < length; i++) {
            Milestone memory milestone = milestones[i];
            if (milestone.approved && !milestone.released) {
                locked += milestone.amount;
            }
        }
    }
}
