// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LendingPoolBasic {
    error InvalidAddress();
    error InvalidPrice();
    error InvalidCollateralFactor();
    error ZeroAmount();
    error InsufficientDeposit();
    error InsufficientCollateral();
    error NotEnoughLiquidity();
    error BorrowExceedsLimit();
    error NoDebt();
    error RepayTooMuch();
    error TransferFailed();

    IERC20 public immutable token;
    uint256 public immutable ethPriceInTokens;
    uint256 public immutable collateralFactorBps;

    uint256 public totalLiquidity;
    uint256 public totalBorrowed;

    mapping(address => uint256) public liquidityDeposits;
    mapping(address => uint256) public collateralBalance;
    mapping(address => uint256) public debtBalance;

    event LiquidityDeposited(address indexed user, uint256 amount);
    event LiquidityWithdrawn(address indexed user, uint256 amount);
    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);

    constructor(address _token, uint256 _ethPriceInTokens, uint256 _collateralFactorBps) {
        if (_token == address(0)) revert InvalidAddress();
        if (_ethPriceInTokens == 0) revert InvalidPrice();
        if (_collateralFactorBps == 0 || _collateralFactorBps > 10000) {
            revert InvalidCollateralFactor();
        }

        token = IERC20(_token);
        ethPriceInTokens = _ethPriceInTokens;
        collateralFactorBps = _collateralFactorBps;
    }

    function depositLiquidity(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        bool success = token.transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        liquidityDeposits[msg.sender] += amount;
        totalLiquidity += amount;

        emit LiquidityDeposited(msg.sender, amount);
    }

    function withdrawLiquidity(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (liquidityDeposits[msg.sender] < amount) revert InsufficientDeposit();
        if (token.balanceOf(address(this)) < amount) revert NotEnoughLiquidity();

        liquidityDeposits[msg.sender] -= amount;
        totalLiquidity -= amount;

        bool success = token.transfer(msg.sender, amount);
        if (!success) revert TransferFailed();

        emit LiquidityWithdrawn(msg.sender, amount);
    }

    function depositCollateral() external payable {
        if (msg.value == 0) revert ZeroAmount();

        collateralBalance[msg.sender] += msg.value;

        emit CollateralDeposited(msg.sender, msg.value);
    }

    function withdrawCollateral(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (collateralBalance[msg.sender] < amount) revert InsufficientCollateral();

        uint256 remainingCollateral = collateralBalance[msg.sender] - amount;
        uint256 maxBorrowAfter = _maxBorrowFromCollateral(remainingCollateral);

        if (debtBalance[msg.sender] > maxBorrowAfter) revert BorrowExceedsLimit();

        collateralBalance[msg.sender] = remainingCollateral;

        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit CollateralWithdrawn(msg.sender, amount);
    }

    function borrow(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (token.balanceOf(address(this)) < amount) revert NotEnoughLiquidity();

        uint256 maxBorrow = getMaxBorrow(msg.sender);
        if (debtBalance[msg.sender] + amount > maxBorrow) revert BorrowExceedsLimit();

        debtBalance[msg.sender] += amount;
        totalBorrowed += amount;

        bool success = token.transfer(msg.sender, amount);
        if (!success) revert TransferFailed();

        emit Borrowed(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (debtBalance[msg.sender] == 0) revert NoDebt();
        if (amount > debtBalance[msg.sender]) revert RepayTooMuch();

        bool success = token.transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        debtBalance[msg.sender] -= amount;
        totalBorrowed -= amount;

        emit Repaid(msg.sender, amount);
    }

    function getMaxBorrow(address user) public view returns (uint256) {
        return _maxBorrowFromCollateral(collateralBalance[user]);
    }

    function getAvailableLiquidity() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function getContractEthBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function _maxBorrowFromCollateral(uint256 collateralAmount) internal view returns (uint256) {
        return (collateralAmount * ethPriceInTokens * collateralFactorBps) / 10000 / 1e18;
    }
}
