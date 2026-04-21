// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract DutchAuction {
    error AuctionExpired();
    error AuctionEnded();
    error InsufficientPayment();
    error InvalidAuctionConfig();
    error TransferFailed();
    error RefundFailed();

    address public immutable seller;
    uint256 public immutable startingPrice;
    uint256 public immutable discountRate;
    uint256 public immutable startAt;
    uint256 public immutable expiresAt;

    bool public ended;
    address public winner;
    uint256 public finalPrice;

    event Purchased(address indexed buyer, uint256 price, uint256 refund);

    constructor(uint256 _startingPrice, uint256 _discountRate, uint256 _duration) {
        if (_startingPrice < (_discountRate * _duration)) {
            revert InvalidAuctionConfig();
        }

        seller = msg.sender;
        startingPrice = _startingPrice;
        discountRate = _discountRate;
        startAt = block.timestamp;
        expiresAt = block.timestamp + _duration;
    }

    function getCurrentPrice() public view returns (uint256) {
        if (ended) {
            return finalPrice;
        }

        uint256 elapsed = block.timestamp >= expiresAt ? expiresAt - startAt : block.timestamp - startAt;

        return startingPrice - (discountRate * elapsed);
    }

    function buy() external payable {
        if (ended) revert AuctionEnded();
        if (block.timestamp >= expiresAt) revert AuctionExpired();

        uint256 price = getCurrentPrice();
        if (msg.value < price) revert InsufficientPayment();

        ended = true;
        winner = msg.sender;
        finalPrice = price;

        uint256 refund = msg.value - price;

        (bool paidSeller,) = payable(seller).call{value: price}("");
        if (!paidSeller) revert TransferFailed();

        if (refund > 0) {
            (bool refunded,) = payable(msg.sender).call{value: refund}("");
            if (!refunded) revert RefundFailed();
        }

        emit Purchased(msg.sender, price, refund);
    }

    function getRemainingTime() external view returns (uint256) {
        if (block.timestamp >= expiresAt) {
            return 0;
        }

        return expiresAt - block.timestamp;
    }
}
