// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTCollection is ERC721 {
    error NotOwner();
    error MintClosed();
    error IncorrectMintPrice();
    error MaxSupplyReached();
    error WithdrawFailed();

    address public immutable owner;
    uint256 public immutable mintPrice;
    uint256 public immutable maxSupply;
    bool public mintOpen;
    uint256 public totalMinted;

    mapping(uint256 => string) private tokenUris;

    event NFTMinted(address indexed minter, uint256 indexed tokenId, string tokenUri);
    event MintStatusChanged(bool isOpen);
    event Withdrawn(address indexed owner, uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(string memory _name, string memory _symbol, uint256 _mintPrice, uint256 _maxSupply)
        ERC721(_name, _symbol)
    {
        owner = msg.sender;
        mintPrice = _mintPrice;
        maxSupply = _maxSupply;
        mintOpen = true;
    }

    function mint(string memory _tokenUri) external payable returns (uint256 tokenId) {
        if (!mintOpen) revert MintClosed();
        if (msg.value != mintPrice) revert IncorrectMintPrice();
        if (totalMinted >= maxSupply) revert MaxSupplyReached();

        tokenId = totalMinted + 1;
        totalMinted = tokenId;

        _safeMint(msg.sender, tokenId);
        tokenUris[tokenId] = _tokenUri;

        emit NFTMinted(msg.sender, tokenId, _tokenUri);
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

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        ownerOf(tokenId);
        return tokenUris[tokenId];
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
