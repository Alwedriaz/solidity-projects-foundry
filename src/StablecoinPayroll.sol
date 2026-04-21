// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StablecoinPayroll {
    error NotOwner();
    error NotAdmin();
    error InvalidAddress();
    error InvalidAmount();
    error InvalidPeriodDuration();
    error RecipientAlreadyExists();
    error RecipientNotFound();
    error RecipientInactive();
    error PayrollPaused();
    error PeriodNotStarted();
    error AlreadyClaimedForCurrentPeriod();
    error InsufficientTreasuryBalance();
    error TransferFailed();

    struct Recipient {
        uint256 amountPerPeriod;
        bool active;
        uint256 lastClaimedPeriod;
        bool exists;
    }

    address public immutable owner;
    IERC20 public immutable stablecoin;
    uint256 public immutable startTime;
    uint256 public immutable periodDuration;

    address public financeManager;
    bool public paused;
    uint256 public totalClaimed;

    mapping(address => Recipient) public recipients;

    event TreasuryDeposited(address indexed owner, uint256 amount);
    event FinanceManagerUpdated(address indexed previousManager, address indexed newManager);
    event PayrollPauseUpdated(bool isPaused);
    event RecipientAdded(address indexed recipient, uint256 amountPerPeriod);
    event RecipientUpdated(address indexed recipient, uint256 amountPerPeriod, bool active);
    event Claimed(address indexed recipient, uint256 indexed period, uint256 amount);
    event TreasuryWithdrawn(address indexed owner, uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyAdmin() {
        if (msg.sender != owner && msg.sender != financeManager) revert NotAdmin();
        _;
    }

    constructor(address _stablecoin, uint256 _startTime, uint256 _periodDuration) {
        if (_stablecoin == address(0)) revert InvalidAddress();
        if (_periodDuration == 0) revert InvalidPeriodDuration();

        owner = msg.sender;
        stablecoin = IERC20(_stablecoin);
        startTime = _startTime;
        periodDuration = _periodDuration;
    }

    function setFinanceManager(address newFinanceManager) external onlyOwner {
        if (newFinanceManager == address(0)) revert InvalidAddress();

        address previousManager = financeManager;
        financeManager = newFinanceManager;

        emit FinanceManagerUpdated(previousManager, newFinanceManager);
    }

    function setPaused(bool isPaused) external onlyOwner {
        paused = isPaused;
        emit PayrollPauseUpdated(isPaused);
    }

    function depositTreasury(uint256 amount) external onlyOwner {
        if (amount == 0) revert InvalidAmount();

        bool success = stablecoin.transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        emit TreasuryDeposited(msg.sender, amount);
    }

    function addRecipient(address recipient, uint256 amountPerPeriod) external onlyAdmin {
        if (recipient == address(0)) revert InvalidAddress();
        if (amountPerPeriod == 0) revert InvalidAmount();
        if (recipients[recipient].exists) revert RecipientAlreadyExists();

        recipients[recipient] =
            Recipient({amountPerPeriod: amountPerPeriod, active: true, lastClaimedPeriod: 0, exists: true});

        emit RecipientAdded(recipient, amountPerPeriod);
    }

    function updateRecipientAmount(address recipient, uint256 newAmountPerPeriod) external onlyAdmin {
        if (!recipients[recipient].exists) revert RecipientNotFound();
        if (newAmountPerPeriod == 0) revert InvalidAmount();

        recipients[recipient].amountPerPeriod = newAmountPerPeriod;

        emit RecipientUpdated(recipient, recipients[recipient].amountPerPeriod, recipients[recipient].active);
    }

    function setRecipientActive(address recipient, bool isActive) external onlyAdmin {
        if (!recipients[recipient].exists) revert RecipientNotFound();

        recipients[recipient].active = isActive;

        emit RecipientUpdated(recipient, recipients[recipient].amountPerPeriod, recipients[recipient].active);
    }

    function claim() external {
        if (paused) revert PayrollPaused();

        Recipient storage recipient = recipients[msg.sender];

        if (!recipient.exists) revert RecipientNotFound();
        if (!recipient.active) revert RecipientInactive();

        uint256 currentPeriod = getCurrentPeriod();
        if (currentPeriod == 0) revert PeriodNotStarted();
        if (recipient.lastClaimedPeriod >= currentPeriod) revert AlreadyClaimedForCurrentPeriod();

        uint256 amount = recipient.amountPerPeriod;
        if (stablecoin.balanceOf(address(this)) < amount) revert InsufficientTreasuryBalance();

        recipient.lastClaimedPeriod = currentPeriod;
        totalClaimed += amount;

        bool success = stablecoin.transfer(msg.sender, amount);
        if (!success) revert TransferFailed();

        emit Claimed(msg.sender, currentPeriod, amount);
    }

    function withdrawTreasury(uint256 amount) external onlyOwner {
        if (amount == 0) revert InvalidAmount();
        if (stablecoin.balanceOf(address(this)) < amount) revert InsufficientTreasuryBalance();

        bool success = stablecoin.transfer(owner, amount);
        if (!success) revert TransferFailed();

        emit TreasuryWithdrawn(owner, amount);
    }

    function getCurrentPeriod() public view returns (uint256) {
        if (block.timestamp < startTime) {
            return 0;
        }

        return ((block.timestamp - startTime) / periodDuration) + 1;
    }

    function getTreasuryBalance() external view returns (uint256) {
        return stablecoin.balanceOf(address(this));
    }
}
