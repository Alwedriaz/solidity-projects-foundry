// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract MerkleAirdrop {
    error NotOwner();
    error AlreadyClaimed();
    error InvalidProof();
    error TransferFailed();

    address public immutable owner;
    IERC20 public immutable token;
    bytes32 public immutable merkleRoot;

    mapping(address => bool) public hasClaimed;

    event Claimed(address indexed account, uint256 amount);
    event Withdrawn(address indexed owner, uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address _token, bytes32 _merkleRoot) {
        owner = msg.sender;
        token = IERC20(_token);
        merkleRoot = _merkleRoot;
    }

    function claim(uint256 amount, bytes32[] calldata proof) external {
        if (hasClaimed[msg.sender]) revert AlreadyClaimed();

        bytes32 leaf = keccak256(abi.encode(msg.sender, amount));
        bool isValid = MerkleProof.verify(proof, merkleRoot, leaf);
        if (!isValid) revert InvalidProof();

        hasClaimed[msg.sender] = true;

        bool success = token.transfer(msg.sender, amount);
        if (!success) revert TransferFailed();

        emit Claimed(msg.sender, amount);
    }

    function withdrawRemainingTokens() external onlyOwner {
        uint256 balance = token.balanceOf(address(this));

        bool success = token.transfer(owner, balance);
        if (!success) revert TransferFailed();

        emit Withdrawn(owner, balance);
    }

    function getContractTokenBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}
