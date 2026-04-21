// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract PaymentSplitter {
    error EmptyPayees();
    error LengthMismatch();
    error ZeroAddressPayee();
    error ZeroShares();
    error DuplicatePayee();
    error NotPayee();
    error NoPaymentDue();
    error TransferFailed();

    uint256 public totalShares;
    uint256 public totalReleased;

    mapping(address => uint256) public shares;
    mapping(address => uint256) public released;
    mapping(address => bool) public isPayee;

    address[] private payees;

    event PayeeAdded(address indexed account, uint256 shares);
    event PaymentReceived(address indexed from, uint256 amount);
    event PaymentReleased(address indexed to, uint256 amount);

    constructor(address[] memory _payees, uint256[] memory _shares) {
        if (_payees.length == 0) revert EmptyPayees();
        if (_payees.length != _shares.length) revert LengthMismatch();

        for (uint256 i = 0; i < _payees.length; i++) {
            address account = _payees[i];
            uint256 share = _shares[i];

            if (account == address(0)) revert ZeroAddressPayee();
            if (share == 0) revert ZeroShares();
            if (isPayee[account]) revert DuplicatePayee();

            isPayee[account] = true;
            shares[account] = share;
            payees.push(account);
            totalShares += share;

            emit PayeeAdded(account, share);
        }
    }

    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }

    function release() external {
        address account = msg.sender;

        if (!isPayee[account]) revert NotPayee();

        uint256 payment = releasable(account);
        if (payment == 0) revert NoPaymentDue();

        released[account] += payment;
        totalReleased += payment;

        (bool success,) = payable(account).call{value: payment}("");
        if (!success) revert TransferFailed();

        emit PaymentReleased(account, payment);
    }

    function releasable(address account) public view returns (uint256) {
        if (!isPayee[account]) return 0;

        uint256 totalReceived = address(this).balance + totalReleased;
        uint256 totalDue = (totalReceived * shares[account]) / totalShares;

        return totalDue - released[account];
    }

    function getPayees() external view returns (address[] memory) {
        return payees;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
