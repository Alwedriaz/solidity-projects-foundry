// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Vesting {
    address public immutable beneficiary;
    uint256 public immutable start;
    uint256 public immutable duration;
    uint256 public released;

    constructor(
        address _beneficiary,
        uint256 _start,
        uint256 _duration
    ) payable {
        require(_beneficiary != address(0), "Beneficiary tidak valid");
        require(_duration > 0, "Durasi harus lebih dari 0");
        require(msg.value > 0, "Harus ada dana awal");

        beneficiary = _beneficiary;
        start = _start;
        duration = _duration;
    }

    function releasable() public view returns (uint256) {
        return vestedAmount(block.timestamp) - released;
    }

    function vestedAmount(uint256 timestamp) public view returns (uint256) {
        uint256 totalAllocation = address(this).balance + released;

        if (timestamp < start) {
            return 0;
        }

        if (timestamp >= start + duration) {
            return totalAllocation;
        }

        uint256 elapsed = timestamp - start;
        return (totalAllocation * elapsed) / duration;
    }

    function release() public {
        require(msg.sender == beneficiary, "Hanya beneficiary yang bisa release");

        uint256 amount = releasable();
        require(amount > 0, "Belum ada dana yang bisa dicairkan");

        released += amount;

        (bool success, ) = payable(beneficiary).call{value: amount}("");
        require(success, "Transfer gagal");
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
}