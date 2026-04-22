// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenLaunchManager {
    error NotOwner();
    error NotAdmin();
    error InvalidAddress();
    error InvalidAmount();
    error InvalidRate();
    error InvalidTime();
    error InvalidUnlockBps();
    error InvalidVestingDuration();
    error SaleNotStarted();
    error SaleEnded();
    error SaleNotEnded();
    error SaleAlreadyFinalized();
    error SaleCancelled();
    error SaleNotFinalized();
    error BuyPaused();
    error ClaimPaused();
    error ExceedsAllocation();
    error NothingPurchased();
    error NothingToClaim();
    error RefundNotAvailable();
    error AlreadyRefunded();
    error WithdrawalNotAvailable();
    error InsufficientAvailableAmount();
    error ArrayLengthMismatch();
    error EmptyBatch();
    error TransferFailed();

    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant RATE_PRECISION = 1e18;

    address public immutable owner;
    address public launchOperator;
    IERC20 public immutable saleToken;
    IERC20 public immutable paymentToken;

    uint256 public immutable saleStart;
    uint256 public immutable saleEnd;
    uint256 public immutable tokenRate;
    uint256 public immutable initialUnlockBps;
    uint256 public immutable vestingDuration;

    bool public finalized;
    bool public cancelled;
    bool public buyPaused;
    bool public claimPaused;
    uint256 public finalizedAt;

    uint256 public totalRaised;
    uint256 public totalTokensSold;
    uint256 public totalClaimedTokens;
    uint256 public totalPaymentWithdrawn;
    uint256 public totalUnsoldWithdrawn;

    mapping(address => uint256) public allocation;
    mapping(address => uint256) public purchasedPayment;
    mapping(address => uint256) public claimedTokens;
    mapping(address => bool) public refunded;

    event LaunchOperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event BuyPauseUpdated(bool isPaused);
    event ClaimPauseUpdated(bool isPaused);
    event AllocationSet(address indexed user, uint256 maxPaymentAmount);
    event TokensPurchased(address indexed buyer, uint256 paymentAmount, uint256 tokenAmount);
    event SaleFinalized(uint256 finalizedAt);
    event SaleCancelledByOwner();
    event TokensClaimed(address indexed user, uint256 amount);
    event Refunded(address indexed user, uint256 paymentAmount);
    event RaisedFundsWithdrawn(address indexed owner, uint256 amount);
    event UnsoldSaleTokensWithdrawn(address indexed owner, uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyAdmin() {
        if (msg.sender != owner && msg.sender != launchOperator) revert NotAdmin();
        _;
    }

    constructor(
        address _saleToken,
        address _paymentToken,
        uint256 _saleStart,
        uint256 _saleEnd,
        uint256 _tokenRate,
        uint256 _initialUnlockBps,
        uint256 _vestingDuration
    ) {
        if (_saleToken == address(0) || _paymentToken == address(0)) {
            revert InvalidAddress();
        }
        if (_tokenRate == 0) revert InvalidRate();
        if (_saleEnd <= _saleStart) revert InvalidTime();
        if (_initialUnlockBps > BPS_DENOMINATOR) revert InvalidUnlockBps();
        if (_vestingDuration == 0) revert InvalidVestingDuration();

        owner = msg.sender;
        saleToken = IERC20(_saleToken);
        paymentToken = IERC20(_paymentToken);
        saleStart = _saleStart;
        saleEnd = _saleEnd;
        tokenRate = _tokenRate;
        initialUnlockBps = _initialUnlockBps;
        vestingDuration = _vestingDuration;
    }

    function setLaunchOperator(address newLaunchOperator) external onlyOwner {
        if (newLaunchOperator == address(0)) revert InvalidAddress();

        address previousOperator = launchOperator;
        launchOperator = newLaunchOperator;

        emit LaunchOperatorUpdated(previousOperator, newLaunchOperator);
    }

    function setBuyPaused(bool isPaused) external onlyAdmin {
        buyPaused = isPaused;
        emit BuyPauseUpdated(isPaused);
    }

    function setClaimPaused(bool isPaused) external onlyAdmin {
        claimPaused = isPaused;
        emit ClaimPauseUpdated(isPaused);
    }

    function setAllocation(address user, uint256 maxPaymentAmount) external onlyAdmin {
        _setAllocation(user, maxPaymentAmount);
    }

    function batchSetAllocation(address[] calldata users, uint256[] calldata maxPaymentAmounts) external onlyAdmin {
        uint256 length = users.length;
        if (length == 0) revert EmptyBatch();
        if (length != maxPaymentAmounts.length) revert ArrayLengthMismatch();

        for (uint256 i = 0; i < length; i++) {
            _setAllocation(users[i], maxPaymentAmounts[i]);
        }
    }

    function buy(uint256 paymentAmount) external {
        if (cancelled) revert SaleCancelled();
        if (finalized) revert SaleAlreadyFinalized();
        if (buyPaused) revert BuyPaused();
        if (block.timestamp < saleStart) revert SaleNotStarted();
        if (block.timestamp >= saleEnd) revert SaleEnded();
        if (paymentAmount == 0) revert InvalidAmount();

        uint256 maxAllocation = allocation[msg.sender];
        if (maxAllocation == 0) revert ExceedsAllocation();
        if (purchasedPayment[msg.sender] + paymentAmount > maxAllocation) {
            revert ExceedsAllocation();
        }

        uint256 tokenAmount = _paymentToTokenAmount(paymentAmount);

        bool success = paymentToken.transferFrom(msg.sender, address(this), paymentAmount);
        if (!success) revert TransferFailed();

        purchasedPayment[msg.sender] += paymentAmount;
        totalRaised += paymentAmount;
        totalTokensSold += tokenAmount;

        emit TokensPurchased(msg.sender, paymentAmount, tokenAmount);
    }

    function finalizeSale() external onlyOwner {
        if (cancelled) revert SaleCancelled();
        if (finalized) revert SaleAlreadyFinalized();
        if (block.timestamp < saleEnd) revert SaleNotEnded();

        finalized = true;
        finalizedAt = block.timestamp;

        emit SaleFinalized(finalizedAt);
    }

    function cancelSale() external onlyOwner {
        if (finalized) revert SaleAlreadyFinalized();
        if (cancelled) revert SaleCancelled();

        cancelled = true;

        emit SaleCancelledByOwner();
    }

    function claim() external {
        if (!finalized) revert SaleNotFinalized();
        if (cancelled) revert SaleCancelled();
        if (claimPaused) revert ClaimPaused();

        uint256 entitlement = purchasedTokenAmount(msg.sender);
        if (entitlement == 0) revert NothingPurchased();

        uint256 claimable = claimableAmount(msg.sender);
        if (claimable == 0) revert NothingToClaim();

        claimedTokens[msg.sender] += claimable;
        totalClaimedTokens += claimable;

        bool success = saleToken.transfer(msg.sender, claimable);
        if (!success) revert TransferFailed();

        emit TokensClaimed(msg.sender, claimable);
    }

    function refund() external {
        if (!cancelled) revert RefundNotAvailable();
        if (refunded[msg.sender]) revert AlreadyRefunded();

        uint256 paymentAmount = purchasedPayment[msg.sender];
        if (paymentAmount == 0) revert NothingPurchased();

        refunded[msg.sender] = true;
        purchasedPayment[msg.sender] = 0;

        uint256 tokenAmount = _paymentToTokenAmount(paymentAmount);
        totalRaised -= paymentAmount;
        totalTokensSold -= tokenAmount;

        bool success = paymentToken.transfer(msg.sender, paymentAmount);
        if (!success) revert TransferFailed();

        emit Refunded(msg.sender, paymentAmount);
    }

    function withdrawRaisedFunds(uint256 amount) external onlyOwner {
        if (!finalized || cancelled) revert WithdrawalNotAvailable();
        if (amount == 0) revert InvalidAmount();

        uint256 available = paymentToken.balanceOf(address(this));
        if (amount > available) revert InsufficientAvailableAmount();

        totalPaymentWithdrawn += amount;

        bool success = paymentToken.transfer(owner, amount);
        if (!success) revert TransferFailed();

        emit RaisedFundsWithdrawn(owner, amount);
    }

    function withdrawUnsoldSaleTokens(uint256 amount) external onlyOwner {
        if (!finalized && !cancelled) revert WithdrawalNotAvailable();
        if (amount == 0) revert InvalidAmount();

        uint256 available = availableUnsoldSaleTokens();
        if (amount > available) revert InsufficientAvailableAmount();

        totalUnsoldWithdrawn += amount;

        bool success = saleToken.transfer(owner, amount);
        if (!success) revert TransferFailed();

        emit UnsoldSaleTokensWithdrawn(owner, amount);
    }

    function purchasedTokenAmount(address user) public view returns (uint256) {
        return _paymentToTokenAmount(purchasedPayment[user]);
    }

    function vestedAmount(address user) public view returns (uint256) {
        if (!finalized || cancelled) {
            return 0;
        }

        uint256 entitlement = purchasedTokenAmount(user);
        if (entitlement == 0) {
            return 0;
        }

        uint256 initialUnlock = (entitlement * initialUnlockBps) / BPS_DENOMINATOR;
        uint256 remaining = entitlement - initialUnlock;
        uint256 elapsed = block.timestamp - finalizedAt;

        if (elapsed >= vestingDuration) {
            return entitlement;
        }

        return initialUnlock + ((remaining * elapsed) / vestingDuration);
    }

    function claimableAmount(address user) public view returns (uint256) {
        uint256 vested = vestedAmount(user);
        uint256 alreadyClaimed = claimedTokens[user];

        if (vested <= alreadyClaimed) {
            return 0;
        }

        return vested - alreadyClaimed;
    }

    function availableUnsoldSaleTokens() public view returns (uint256) {
        uint256 balance = saleToken.balanceOf(address(this));

        if (cancelled) {
            return balance;
        }

        if (!finalized) {
            return 0;
        }

        uint256 requiredForClaims = totalTokensSold - totalClaimedTokens;

        if (balance <= requiredForClaims) {
            return 0;
        }

        return balance - requiredForClaims;
    }

    function getPaymentTokenBalance() external view returns (uint256) {
        return paymentToken.balanceOf(address(this));
    }

    function getSaleTokenBalance() external view returns (uint256) {
        return saleToken.balanceOf(address(this));
    }

    function _paymentToTokenAmount(uint256 paymentAmount) internal view returns (uint256) {
        return (paymentAmount * tokenRate) / RATE_PRECISION;
    }

    function _setAllocation(address user, uint256 maxPaymentAmount) internal {
        if (user == address(0)) revert InvalidAddress();
        if (maxPaymentAmount == 0) revert InvalidAmount();

        allocation[user] = maxPaymentAmount;
        emit AllocationSet(user, maxPaymentAmount);
    }
}
