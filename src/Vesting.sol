// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.33;

contract Vesting {
    address public immutable BENEFICIARY;
    uint256 public immutable START;
    uint256 public immutable DURATION;
    uint256 public released;

    constructor(address _beneficiary, uint256 _start, uint256 _duration) payable {
        require(_beneficiary != address(0), "Beneficiary tidak valid");
        require(_duration > 0, "Durasi harus lebih dari 0");
        require(msg.value > 0, "Harus ada dana awal");

        BENEFICIARY = _beneficiary;
        START = _start;
        DURATION = _duration;
    }

    function releasable() public view returns (uint256) {
        return vestedAmount(block.timestamp) - released;
    }

    function vestedAmount(uint256 timestamp) public view returns (uint256) {
        uint256 totalAllocation = address(this).balance + released;

        if (timestamp < START) {
            return 0;
        }

        if (timestamp >= START + DURATION) {
            return totalAllocation;
        }

        uint256 elapsed = timestamp - START;
        return (totalAllocation * elapsed) / DURATION;
    }

    function release() public {
        require(msg.sender == BENEFICIARY, "Hanya beneficiary yang bisa release");

        uint256 amount = releasable();
        require(amount > 0, "Belum ada dana yang bisa dicairkan");

        released += amount;

        (bool success,) = payable(BENEFICIARY).call{value: amount}("");
        require(success, "Transfer gagal");
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
