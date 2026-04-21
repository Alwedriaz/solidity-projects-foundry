// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {WhitelistNFTMint} from "../src/WhitelistNFTMint.sol";

contract WhitelistNFTMintTest is Test {
    WhitelistNFTMint nft;

    address owner = address(0xA11CE);
    address user1 = address(0x1);
    address user2 = address(0x2);
    address outsider = address(0x99);

    uint256 constant MINT_PRICE = 0.1 ether;
    uint256 constant MAX_SUPPLY = 2;

    string constant NAME = "WhitelistNFT";
    string constant SYMBOL = "WNFT";

    bytes32 root;
    bytes32[] proofUser1;
    bytes32[] proofUser2;

    function setUp() public {
        bytes32 leaf1 = keccak256(abi.encodePacked(user1));
        bytes32 leaf2 = keccak256(abi.encodePacked(user2));

        root = hashPair(leaf1, leaf2);

        proofUser1.push(leaf2);
        proofUser2.push(leaf1);

        vm.prank(owner);
        nft = new WhitelistNFTMint(NAME, SYMBOL, root, MINT_PRICE, MAX_SUPPLY);

        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(outsider, 10 ether);
        vm.deal(owner, 0);
    }

    function testConstructorSetsInitialValues() public view {
        assertEq(nft.owner(), owner);
        assertEq(nft.name(), NAME);
        assertEq(nft.symbol(), SYMBOL);
        assertEq(nft.merkleRoot(), root);
        assertEq(nft.mintPrice(), MINT_PRICE);
        assertEq(nft.maxSupply(), MAX_SUPPLY);
        assertTrue(nft.mintOpen());
    }

    function testWhitelistMintRevertsIfMintClosed() public {
        vm.prank(owner);
        nft.setMintOpen(false);

        vm.prank(user1);
        vm.expectRevert(WhitelistNFTMint.MintClosed.selector);
        nft.whitelistMint{value: MINT_PRICE}(proofUser1);
    }

    function testWhitelistMintRevertsIfIncorrectPrice() public {
        vm.prank(user1);
        vm.expectRevert(WhitelistNFTMint.IncorrectMintPrice.selector);
        nft.whitelistMint{value: 0.05 ether}(proofUser1);
    }

    function testWhitelistMintRevertsIfProofInvalid() public {
        vm.prank(outsider);
        vm.expectRevert(WhitelistNFTMint.InvalidProof.selector);
        nft.whitelistMint{value: MINT_PRICE}(proofUser1);
    }

    function testWhitelistMintStoresOwnerAndSupply() public {
        vm.prank(user1);
        nft.whitelistMint{value: MINT_PRICE}(proofUser1);

        assertEq(nft.ownerOf(1), user1);
        assertTrue(nft.hasMinted(user1));
        assertEq(nft.totalMinted(), 1);
        assertEq(nft.getContractBalance(), MINT_PRICE);
    }

    function testWhitelistMintRevertsIfUserAlreadyMinted() public {
        vm.prank(user1);
        nft.whitelistMint{value: MINT_PRICE}(proofUser1);

        vm.prank(user1);
        vm.expectRevert(WhitelistNFTMint.AlreadyMinted.selector);
        nft.whitelistMint{value: MINT_PRICE}(proofUser1);
    }

    function testWhitelistMintRevertsWhenMaxSupplyReached() public {
        vm.prank(user1);
        nft.whitelistMint{value: MINT_PRICE}(proofUser1);

        vm.prank(user2);
        nft.whitelistMint{value: MINT_PRICE}(proofUser2);

        vm.prank(owner);
        WhitelistNFTMint smallNft = new WhitelistNFTMint(NAME, SYMBOL, root, MINT_PRICE, 1);

        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);

        vm.prank(user1);
        smallNft.whitelistMint{value: MINT_PRICE}(proofUser1);

        vm.prank(user2);
        vm.expectRevert(WhitelistNFTMint.MaxSupplyReached.selector);
        smallNft.whitelistMint{value: MINT_PRICE}(proofUser2);
    }

    function testOnlyOwnerCanSetMintOpen() public {
        vm.prank(user1);
        vm.expectRevert(WhitelistNFTMint.NotOwner.selector);
        nft.setMintOpen(false);
    }

    function testOnlyOwnerCanWithdraw() public {
        vm.prank(user1);
        vm.expectRevert(WhitelistNFTMint.NotOwner.selector);
        nft.withdraw();
    }

    function testWithdrawTransfersBalanceToOwner() public {
        vm.prank(user1);
        nft.whitelistMint{value: MINT_PRICE}(proofUser1);

        vm.prank(user2);
        nft.whitelistMint{value: MINT_PRICE}(proofUser2);

        uint256 ownerBalanceBefore = owner.balance;

        vm.prank(owner);
        nft.withdraw();

        assertEq(address(nft).balance, 0);
        assertEq(owner.balance, ownerBalanceBefore + (2 * MINT_PRICE));
    }

    function hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }
}
