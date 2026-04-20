// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.33;

contract Crowdfunding {
    address public owner;
    uint256 public goal;
    uint256 public deadline;
    uint256 public totalRaised;
    bool public claimed;

    mapping(address => uint256) public contributions;

    event Contributed(address indexed user, uint256 amount);
    event FundsClaimed(address indexed owner, uint256 amount);
    event Refunded(address indexed user, uint256 amount);

    constructor(uint256 _goal, uint256 _duration) {
        require(_goal > 0, "Target harus lebih dari 0");
        require(_duration > 0, "Durasi harus lebih dari 0");

        owner = msg.sender;
        goal = _goal;
        deadline = block.timestamp + _duration;
    }

    function contribute() public payable {
        require(block.timestamp < deadline, "Campaign sudah berakhir");
        require(msg.value > 0, "Jumlah harus lebih dari 0");

        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;

        emit Contributed(msg.sender, msg.value);
    }

    function claimFunds() public {
        require(msg.sender == owner, "Hanya owner yang bisa claim");
        require(block.timestamp >= deadline, "Campaign belum selesai");
        require(totalRaised >= goal, "Target belum tercapai");
        require(!claimed, "Dana sudah di-claim");

        claimed = true;
        uint256 amount = address(this).balance;

        (bool success, ) = payable(owner).call{value: amount}("");
        require(success, "Transfer gagal");

        emit FundsClaimed(owner, amount);
    }

    function refund() public {
        require(block.timestamp >= deadline, "Campaign belum selesai");
        require(totalRaised < goal, "Target tercapai, refund tidak tersedia");

        uint256 amount = contributions[msg.sender];
        require(amount > 0, "Tidak ada dana untuk direfund");

        contributions[msg.sender] = 0;
        totalRaised -= amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer gagal");

        emit Refunded(msg.sender, amount);
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
}