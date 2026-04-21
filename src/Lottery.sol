// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Lottery {
    error NotOwner();
    error LotteryClosed();
    error InsufficientEntryFee();
    error NoPlayersEntered();
    error TransferFailed();

    address public immutable owner;
    uint256 public immutable entranceFee;
    bool public lotteryOpen;
    address public lastWinner;

    address[] private players;

    event LotteryEntered(address indexed player, uint256 amount);
    event WinnerPicked(address indexed winner, uint256 prize);
    event LotteryStatusChanged(bool isOpen);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(uint256 _entranceFee) {
        owner = msg.sender;
        entranceFee = _entranceFee;
        lotteryOpen = true;
    }

    function enterLottery() external payable {
        if (!lotteryOpen) revert LotteryClosed();
        if (msg.value < entranceFee) revert InsufficientEntryFee();

        players.push(msg.sender);
        emit LotteryEntered(msg.sender, msg.value);
    }

    function drawWinner() external onlyOwner returns (address winner) {
        uint256 playersLength = players.length;
        if (playersLength == 0) revert NoPlayersEntered();

        uint256 randomIndex = uint256(
            keccak256(abi.encodePacked(block.prevrandao, block.timestamp, playersLength, address(this).balance))
        ) % playersLength;

        winner = players[randomIndex];
        uint256 prize = address(this).balance;

        lastWinner = winner;
        delete players;

        (bool success,) = payable(winner).call{value: prize}("");
        if (!success) revert TransferFailed();

        emit WinnerPicked(winner, prize);
    }

    function setLotteryOpen(bool _isOpen) external onlyOwner {
        lotteryOpen = _isOpen;
        emit LotteryStatusChanged(_isOpen);
    }

    function getPlayers() external view returns (address[] memory) {
        return players;
    }

    function getPlayersCount() external view returns (uint256) {
        return players.length;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
