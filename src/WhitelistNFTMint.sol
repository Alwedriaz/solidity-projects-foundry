// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract WhitelistNFTMint is ERC721 {
    error NotOwner();
    error MintClosed();
    error IncorrectMintPrice();
    error InvalidProof();
    error AlreadyMinted();
    error MaxSupplyReached();
    error WithdrawFailed();

    address public immutable owner;
    bytes32 public immutable merkleRoot;
    uint256 public immutable mintPrice;
    uint256 public immutable maxSupply;

    bool public mintOpen;
    uint256 public totalMinted;

    mapping(address => bool) public hasMinted;

    event MintStatusChanged(bool isOpen);
    event WhitelistMinted(address indexed minter, uint256 indexed tokenId);
    event Withdrawn(address indexed owner, uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(string memory _name, string memory _symbol, bytes32 _merkleRoot, uint256 _mintPrice, uint256 _maxSupply)
        ERC721(_name, _symbol)
    {
        owner = msg.sender;
        merkleRoot = _merkleRoot;
        mintPrice = _mintPrice;
        maxSupply = _maxSupply;
        mintOpen = true;
    }

    function whitelistMint(bytes32[] calldata proof) external payable returns (uint256 tokenId) {
        if (!mintOpen) revert MintClosed();
        if (msg.value != mintPrice) revert IncorrectMintPrice();
        if (hasMinted[msg.sender]) revert AlreadyMinted();

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        bool isValid = MerkleProof.verify(proof, merkleRoot, leaf);
        if (!isValid) revert InvalidProof();

        if (totalMinted >= maxSupply) revert MaxSupplyReached();

        hasMinted[msg.sender] = true;

        tokenId = totalMinted + 1;
        totalMinted = tokenId;

        _safeMint(msg.sender, tokenId);

        emit WhitelistMinted(msg.sender, tokenId);
    }

    function setMintOpen(bool _isOpen) external onlyOwner {
        mintOpen = _isOpen;
        emit MintStatusChanged(_isOpen);
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;

        (bool success,) = payable(owner).call{value: balance}("");
        if (!success) revert WithdrawFailed();

        emit Withdrawn(owner, balance);
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
