// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.33;

contract TimelockWallet {
    address public immutable owner;
    uint256 public immutable unlockTime;

    event Deposited(address indexed sender, uint256 amount);
    event Withdrawn(address indexed owner, uint256 amount);

    constructor(uint256 _unlockTime) payable {
        require(_unlockTime > block.timestamp, "Waktu unlock harus di masa depan");
        require(msg.value > 0, "Harus ada dana awal");

        owner = msg.sender;
        unlockTime = _unlockTime;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Hanya owner yang bisa withdraw");
        _;
    }

    receive() external payable {
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw() public onlyOwner {
        require(block.timestamp >= unlockTime, "Dana masih terkunci");

        uint256 amount = address(this).balance;
        require(amount > 0, "Tidak ada dana");

        (bool success, ) = payable(owner).call{value: amount}("");
        require(success, "Transfer gagal");

        emit Withdrawn(owner, amount);
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}