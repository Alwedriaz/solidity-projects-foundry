// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MultiSigTreasuryAdvanced {
    error NotOwner();
    error InvalidOwner();
    error DuplicateOwner();
    error InvalidRequiredConfirmations();
    error InvalidRecipient();
    error EmptyTransaction();
    error InvalidTransactionId();
    error AlreadyConfirmed();
    error NotConfirmed();
    error AlreadyExecuted();
    error NotEnoughConfirmations();
    error InsufficientTreasuryBalance();
    error ExecutionFailed();

    struct Transaction {
        address recipient;
        uint256 amount;
        bytes data;
        uint256 confirmations;
        bool executed;
    }

    address[] private owners;
    mapping(address => bool) public isOwner;
    mapping(uint256 => mapping(address => bool)) public hasConfirmed;

    uint256 public immutable requiredConfirmations;
    Transaction[] private transactions;

    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event TransactionSubmitted(uint256 indexed txId, address indexed recipient, uint256 amount, bytes data);
    event TransactionConfirmed(uint256 indexed txId, address indexed owner);
    event ConfirmationRevoked(uint256 indexed txId, address indexed owner);
    event TransactionExecuted(uint256 indexed txId, address indexed executor);

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert NotOwner();
        _;
    }

    constructor(address[] memory _owners, uint256 _requiredConfirmations) {
        if (_owners.length == 0) revert InvalidOwner();
        if (_requiredConfirmations == 0 || _requiredConfirmations > _owners.length) {
            revert InvalidRequiredConfirmations();
        }

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            if (owner == address(0)) revert InvalidOwner();
            if (isOwner[owner]) revert DuplicateOwner();

            isOwner[owner] = true;
            owners.push(owner);
        }

        requiredConfirmations = _requiredConfirmations;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function submitTransaction(address recipient, uint256 amount, bytes calldata data)
        external
        onlyOwner
        returns (uint256 txId)
    {
        if (recipient == address(0)) revert InvalidRecipient();
        if (amount == 0 && data.length == 0) revert EmptyTransaction();

        txId = transactions.length;
        transactions.push(
            Transaction({recipient: recipient, amount: amount, data: data, confirmations: 0, executed: false})
        );

        emit TransactionSubmitted(txId, recipient, amount, data);
    }

    function confirmTransaction(uint256 txId) external onlyOwner {
        if (txId >= transactions.length) revert InvalidTransactionId();

        Transaction storage txn = transactions[txId];

        if (txn.executed) revert AlreadyExecuted();
        if (hasConfirmed[txId][msg.sender]) revert AlreadyConfirmed();

        hasConfirmed[txId][msg.sender] = true;
        txn.confirmations += 1;

        emit TransactionConfirmed(txId, msg.sender);
    }

    function revokeConfirmation(uint256 txId) external onlyOwner {
        if (txId >= transactions.length) revert InvalidTransactionId();

        Transaction storage txn = transactions[txId];

        if (txn.executed) revert AlreadyExecuted();
        if (!hasConfirmed[txId][msg.sender]) revert NotConfirmed();

        hasConfirmed[txId][msg.sender] = false;
        txn.confirmations -= 1;

        emit ConfirmationRevoked(txId, msg.sender);
    }

    function executeTransaction(uint256 txId) external onlyOwner {
        if (txId >= transactions.length) revert InvalidTransactionId();

        Transaction storage txn = transactions[txId];

        if (txn.executed) revert AlreadyExecuted();
        if (txn.confirmations < requiredConfirmations) {
            revert NotEnoughConfirmations();
        }
        if (address(this).balance < txn.amount) {
            revert InsufficientTreasuryBalance();
        }

        txn.executed = true;

        (bool success,) = txn.recipient.call{value: txn.amount}(txn.data);
        if (!success) revert ExecutionFailed();

        emit TransactionExecuted(txId, msg.sender);
    }

    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    function getTransaction(uint256 txId)
        external
        view
        returns (address recipient, uint256 amount, bytes memory data, uint256 confirmations, bool executed)
    {
        if (txId >= transactions.length) revert InvalidTransactionId();

        Transaction memory txn = transactions[txId];
        return (txn.recipient, txn.amount, txn.data, txn.confirmations, txn.executed);
    }

    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }

    function getTreasuryBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
