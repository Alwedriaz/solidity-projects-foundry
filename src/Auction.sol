// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.33;

contract Auction {
    address public owner;
    uint256 public auctionEndTime;
    bool public ended;

    address public highestBidder;
    uint256 public highestBid;

    mapping(address => uint256) public pendingReturns;

    event BidPlaced(address indexed bidder, uint256 amount);
    event RefundWithdrawn(address indexed bidder, uint256 amount);
    event AuctionEnded(address indexed winner, uint256 amount);

    constructor(uint256 _duration) {
        require(_duration > 0, "Durasi harus lebih dari 0");

        owner = msg.sender;
        auctionEndTime = block.timestamp + _duration;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Hanya owner");
        _;
    }

    function bid() public payable {
        require(block.timestamp < auctionEndTime, "Auction sudah selesai");
        require(msg.value > highestBid, "Bid harus lebih tinggi");
        require(msg.sender != owner, "Owner tidak bisa bid");

        if (highestBidder != address(0)) {
            pendingReturns[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid = msg.value;

        emit BidPlaced(msg.sender, msg.value);
    }

    function withdrawRefund() public {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "Tidak ada refund");

        pendingReturns[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer gagal");

        emit RefundWithdrawn(msg.sender, amount);
    }

    function endAuction() public onlyOwner {
        require(block.timestamp >= auctionEndTime, "Auction belum selesai");
        require(!ended, "Auction sudah diakhiri");

        ended = true;

        if (highestBid > 0) {
            (bool success, ) = payable(owner).call{value: highestBid}("");
            require(success, "Transfer gagal");
        }

        emit AuctionEnded(highestBidder, highestBid);
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}