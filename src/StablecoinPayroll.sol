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
    error PayrollPaused();
    error PeriodNotStarted();
    error NothingToClaim();
    error InsufficientTreasuryBalance();
    error TransferFailed();
    error ArrayLengthMismatch();
    error EmptyBatch();

    struct Recipient {
        uint256 amountPerPeriod;
        bool active;
        uint256 lastAccruedPeriod;
        uint256 startPeriod;
        uint256 accruedBalance;
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
    event RecipientAdded(address indexed recipient, uint256 amountPerPeriod, uint256 startPeriod);
    event RecipientUpdated(address indexed recipient, uint256 amountPerPeriod, bool active, uint256 accruedBalance);
    event Claimed(address indexed recipient, uint256 amount);
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
        _addRecipient(recipient, amountPerPeriod);
    }

    function batchAddRecipients(address[] calldata recipientAddresses, uint256[] calldata amountsPerPeriod)
        external
        onlyAdmin
    {
        uint256 length = recipientAddresses.length;
        if (length == 0) revert EmptyBatch();
        if (length != amountsPerPeriod.length) revert ArrayLengthMismatch();

        for (uint256 i = 0; i < length; i++) {
            _addRecipient(recipientAddresses[i], amountsPerPeriod[i]);
        }
    }

    function updateRecipientAmount(address recipient, uint256 newAmountPerPeriod) external onlyAdmin {
        _updateRecipientAmount(recipient, newAmountPerPeriod);
    }

    function batchUpdateRecipientAmounts(address[] calldata recipientAddresses, uint256[] calldata newAmountsPerPeriod)
        external
        onlyAdmin
    {
        uint256 length = recipientAddresses.length;
        if (length == 0) revert EmptyBatch();
        if (length != newAmountsPerPeriod.length) revert ArrayLengthMismatch();

        for (uint256 i = 0; i < length; i++) {
            _updateRecipientAmount(recipientAddresses[i], newAmountsPerPeriod[i]);
        }
    }

    function setRecipientActive(address recipient, bool isActive) external onlyAdmin {
        _setRecipientActive(recipient, isActive);
    }

    function batchSetRecipientActive(address[] calldata recipientAddresses, bool[] calldata statuses)
        external
        onlyAdmin
    {
        uint256 length = recipientAddresses.length;
        if (length == 0) revert EmptyBatch();
        if (length != statuses.length) revert ArrayLengthMismatch();

        for (uint256 i = 0; i < length; i++) {
            _setRecipientActive(recipientAddresses[i], statuses[i]);
        }
    }

    function claim() external {
        if (paused) revert PayrollPaused();

        Recipient storage user = recipients[msg.sender];
        if (!user.exists) revert RecipientNotFound();

        _accrue(msg.sender);

        uint256 amount = user.accruedBalance;
        if (amount == 0) revert NothingToClaim();
        if (stablecoin.balanceOf(address(this)) < amount) revert InsufficientTreasuryBalance();

        user.accruedBalance = 0;
        totalClaimed += amount;

        bool success = stablecoin.transfer(msg.sender, amount);
        if (!success) revert TransferFailed();

        emit Claimed(msg.sender, amount);
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

    function previewClaimable(address recipient) external view returns (uint256) {
        Recipient memory user = recipients[recipient];
        if (!user.exists) return 0;

        uint256 accrued = user.accruedBalance;
        uint256 currentPeriod = getCurrentPeriod();

        if (!user.active || currentPeriod == 0) {
            return accrued;
        }

        if (currentPeriod > user.lastAccruedPeriod) {
            uint256 periodsToAccrue = currentPeriod - user.lastAccruedPeriod;
            accrued += periodsToAccrue * user.amountPerPeriod;
        }

        return accrued;
    }

    function _addRecipient(address recipient, uint256 amountPerPeriod) internal {
        if (recipient == address(0)) revert InvalidAddress();
        if (amountPerPeriod == 0) revert InvalidAmount();
        if (recipients[recipient].exists) revert RecipientAlreadyExists();

        uint256 currentPeriod = getCurrentPeriod();
        uint256 recipientStartPeriod = currentPeriod == 0 ? 1 : currentPeriod;

        recipients[recipient] = Recipient({
            amountPerPeriod: amountPerPeriod,
            active: true,
            lastAccruedPeriod: recipientStartPeriod - 1,
            startPeriod: recipientStartPeriod,
            accruedBalance: 0,
            exists: true
        });

        emit RecipientAdded(recipient, amountPerPeriod, recipientStartPeriod);
    }

    function _updateRecipientAmount(address recipient, uint256 newAmountPerPeriod) internal {
        if (!recipients[recipient].exists) revert RecipientNotFound();
        if (newAmountPerPeriod == 0) revert InvalidAmount();

        if (getCurrentPeriod() != 0) {
            _accrue(recipient);
        }

        recipients[recipient].amountPerPeriod = newAmountPerPeriod;

        emit RecipientUpdated(
            recipient,
            recipients[recipient].amountPerPeriod,
            recipients[recipient].active,
            recipients[recipient].accruedBalance
        );
    }

    function _setRecipientActive(address recipient, bool isActive) internal {
        if (!recipients[recipient].exists) revert RecipientNotFound();

        Recipient storage user = recipients[recipient];
        uint256 currentPeriod = getCurrentPeriod();

        if (user.active && !isActive) {
            if (currentPeriod != 0) {
                _accrue(recipient);
            }
            user.active = false;
        } else if (!user.active && isActive) {
            if (currentPeriod == 0) {
                user.lastAccruedPeriod = user.startPeriod - 1;
            } else {
                user.lastAccruedPeriod = currentPeriod - 1;
            }

            user.active = true;
        }

        emit RecipientUpdated(recipient, user.amountPerPeriod, user.active, user.accruedBalance);
    }

    function _accrue(address recipient) internal {
        Recipient storage user = recipients[recipient];

        if (!user.exists) revert RecipientNotFound();

        uint256 currentPeriod = getCurrentPeriod();
        if (currentPeriod == 0) revert PeriodNotStarted();
        if (!user.active) return;

        if (currentPeriod > user.lastAccruedPeriod) {
            uint256 periodsToAccrue = currentPeriod - user.lastAccruedPeriod;
            user.accruedBalance += periodsToAccrue * user.amountPerPeriod;
            user.lastAccruedPeriod = currentPeriod;
        }
    }
}
