// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Escrow {
    address public buyer;
    address public seller;
    bool public isFunded;
    bool public isReleased;

    constructor(address _buyer, address _seller) {
        buyer = _buyer;
        seller = _seller;
    }

    function deposit() public payable {
        require(msg.sender == buyer, "Hanya buyer yang bisa deposit");
        require(!isFunded, "Dana sudah dideposit");
        require(msg.value > 0, "Jumlah harus lebih dari 0");

        isFunded = true;
    }

    function release() public {
        require(msg.sender == buyer, "Hanya buyer yang bisa release");
        require(isFunded, "Dana belum ada");
        require(!isReleased, "Dana sudah dilepas");

        isReleased = true;

        (bool success, ) = payable(seller).call{value: address(this).balance}("");
        require(success, "Transfer gagal");
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
}