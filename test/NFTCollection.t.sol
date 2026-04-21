// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {NFTCollection} from "../src/NFTCollection.sol";

contract NFTCollectionTest is Test {
    NFTCollection nft;

    address owner = address(0xA11CE);
    address user1 = address(0x1);
    address user2 = address(0x2);
    address user3 = address(0x3);

    uint256 constant MINT_PRICE = 0.1 ether;
    uint256 constant MAX_SUPPLY = 5;

    string constant NAME = "LearnNFT";
    string constant SYMBOL = "LNFT";
    string constant TOKEN_URI_1 = "ipfs://token-1";
    string constant TOKEN_URI_2 = "ipfs://token-2";
    string constant TOKEN_URI_3 = "ipfs://token-3";

    function setUp() public {
        vm.prank(owner);
        nft = new NFTCollection(NAME, SYMBOL, MINT_PRICE, MAX_SUPPLY);

        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        vm.deal(owner, 0);
    }

    function testConstructorSetsInitialValues() public view {
        assertEq(nft.owner(), owner);
        assertEq(nft.name(), NAME);
        assertEq(nft.symbol(), SYMBOL);
        assertEq(nft.mintPrice(), MINT_PRICE);
        assertEq(nft.maxSupply(), MAX_SUPPLY);
        assertTrue(nft.mintOpen());
    }

    function testMintRevertsIfMintClosed() public {
        vm.prank(owner);
        nft.setMintOpen(false);

        vm.prank(user1);
        vm.expectRevert(NFTCollection.MintClosed.selector);
        nft.mint{value: MINT_PRICE}(TOKEN_URI_1);
    }

    function testMintRevertsIfIncorrectPrice() public {
        vm.prank(user1);
        vm.expectRevert(NFTCollection.IncorrectMintPrice.selector);
        nft.mint{value: 0.05 ether}(TOKEN_URI_1);
    }

    function testMintStoresOwnerTokenUriAndSupply() public {
        vm.prank(user1);
        nft.mint{value: MINT_PRICE}(TOKEN_URI_1);

        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.tokenURI(1), TOKEN_URI_1);
        assertEq(nft.totalMinted(), 1);
        assertEq(nft.getContractBalance(), MINT_PRICE);
    }

    function testOnlyOwnerCanSetMintOpen() public {
        vm.prank(user1);
        vm.expectRevert(NFTCollection.NotOwner.selector);
        nft.setMintOpen(false);
    }

    function testOnlyOwnerCanWithdraw() public {
        vm.prank(user1);
        vm.expectRevert(NFTCollection.NotOwner.selector);
        nft.withdraw();
    }

    function testWithdrawTransfersBalanceToOwner() public {
        vm.prank(user1);
        nft.mint{value: MINT_PRICE}(TOKEN_URI_1);

        vm.prank(user2);
        nft.mint{value: MINT_PRICE}(TOKEN_URI_2);

        uint256 ownerBalanceBefore = owner.balance;

        vm.prank(owner);
        nft.withdraw();

        assertEq(address(nft).balance, 0);
        assertEq(owner.balance, ownerBalanceBefore + (2 * MINT_PRICE));
    }

    function testMintRevertsWhenMaxSupplyReached() public {
        vm.prank(owner);
        NFTCollection smallNft = new NFTCollection(NAME, SYMBOL, MINT_PRICE, 2);

        vm.prank(user1);
        smallNft.mint{value: MINT_PRICE}(TOKEN_URI_1);

        vm.prank(user2);
        smallNft.mint{value: MINT_PRICE}(TOKEN_URI_2);

        vm.prank(user3);
        vm.expectRevert(NFTCollection.MaxSupplyReached.selector);
        smallNft.mint{value: MINT_PRICE}(TOKEN_URI_3);
    }
}
