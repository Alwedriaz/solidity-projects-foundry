// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Crowdsale {
    error NotOwner();
    error InvalidAddress();
    error InvalidRate();
    error InvalidDuration();
    error ZeroEthSent();
    error SaleNotStarted();
    error SaleEnded();
    error SaleClosed();
    error InsufficientTokenBalance();
    error NothingToWithdraw();
    error TransferFailed();

    address public immutable owner;
    IERC20 public immutable token;
    uint256 public immutable rate;
    uint256 public immutable startAt;
    uint256 public immutable endAt;

    bool public saleClosed;
    uint256 public totalRaised;
    uint256 public totalTokensSold;

    mapping(address => uint256) public purchasedTokens;

    event TokensPurchased(address indexed buyer, uint256 ethSpent, uint256 tokensBought);
    event SaleClosedByOwner();
    event EthWithdrawn(address indexed owner, uint256 amount);
    event UnsoldTokensWithdrawn(address indexed owner, uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address _token, uint256 _rate, uint256 _startAt, uint256 _duration) {
        if (_token == address(0)) revert InvalidAddress();
        if (_rate == 0) revert InvalidRate();
        if (_duration == 0) revert InvalidDuration();

        owner = msg.sender;
        token = IERC20(_token);
        rate = _rate;
        startAt = _startAt;
        endAt = _startAt + _duration;
    }

    function buyTokens() external payable {
        if (saleClosed) revert SaleClosed();
        if (msg.value == 0) revert ZeroEthSent();
        if (block.timestamp < startAt) revert SaleNotStarted();
        if (block.timestamp >= endAt) revert SaleEnded();

        uint256 tokensToBuy = msg.value * rate;

        if (token.balanceOf(address(this)) < tokensToBuy) {
            revert InsufficientTokenBalance();
        }

        totalRaised += msg.value;
        totalTokensSold += tokensToBuy;
        purchasedTokens[msg.sender] += tokensToBuy;

        bool success = token.transfer(msg.sender, tokensToBuy);
        if (!success) revert TransferFailed();

        emit TokensPurchased(msg.sender, msg.value, tokensToBuy);
    }

    function closeSale() external onlyOwner {
        saleClosed = true;
        emit SaleClosedByOwner();
    }

    function withdrawETH() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) revert NothingToWithdraw();

        (bool success,) = payable(owner).call{value: balance}("");
        if (!success) revert TransferFailed();

        emit EthWithdrawn(owner, balance);
    }

    function withdrawUnsoldTokens() external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        if (balance == 0) revert NothingToWithdraw();

        bool success = token.transfer(owner, balance);
        if (!success) revert TransferFailed();

        emit UnsoldTokensWithdrawn(owner, balance);
    }

    function getContractTokenBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function getContractEthBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
