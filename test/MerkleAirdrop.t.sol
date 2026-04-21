// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";

contract MockToken is ERC20 {
    constructor() ERC20("MockToken", "MTK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MerkleAirdropTest is Test {
    MockToken token;
    MerkleAirdrop airdrop;

    address owner = address(this);
    address user1 = address(0x1);
    address user2 = address(0x2);
    address user3 = address(0x3);

    uint256 constant AMOUNT_USER1 = 100 ether;
    uint256 constant AMOUNT_USER2 = 200 ether;
    uint256 constant EXTRA_TOKENS = 50 ether;

    bytes32 root;
    bytes32[] proofUser1;
    bytes32[] proofUser2;

    function setUp() public {
        token = new MockToken();

        bytes32 leaf1 = keccak256(abi.encode(user1, AMOUNT_USER1));
        bytes32 leaf2 = keccak256(abi.encode(user2, AMOUNT_USER2));

        root = hashPair(leaf1, leaf2);

        proofUser1.push(leaf2);
        proofUser2.push(leaf1);

        airdrop = new MerkleAirdrop(address(token), root);

        token.mint(address(airdrop), AMOUNT_USER1 + AMOUNT_USER2 + EXTRA_TOKENS);
    }

    function testConstructorSetsInitialValues() public view {
        assertEq(airdrop.owner(), owner);
        assertEq(address(airdrop.token()), address(token));
        assertEq(airdrop.merkleRoot(), root);
    }

    function testClaimTransfersTokensAndMarksClaimed() public {
        vm.prank(user1);
        airdrop.claim(AMOUNT_USER1, proofUser1);

        assertEq(token.balanceOf(user1), AMOUNT_USER1);
        assertTrue(airdrop.hasClaimed(user1));
        assertEq(token.balanceOf(address(airdrop)), AMOUNT_USER2 + EXTRA_TOKENS);
    }

    function testClaimRevertsWithInvalidProof() public {
        vm.prank(user3);
        vm.expectRevert(MerkleAirdrop.InvalidProof.selector);
        airdrop.claim(AMOUNT_USER1, proofUser1);
    }

    function testClaimRevertsIfAlreadyClaimed() public {
        vm.prank(user1);
        airdrop.claim(AMOUNT_USER1, proofUser1);

        vm.prank(user1);
        vm.expectRevert(MerkleAirdrop.AlreadyClaimed.selector);
        airdrop.claim(AMOUNT_USER1, proofUser1);
    }

    function testClaimRevertsIfAmountDoesNotMatchProof() public {
        vm.prank(user1);
        vm.expectRevert(MerkleAirdrop.InvalidProof.selector);
        airdrop.claim(999 ether, proofUser1);
    }

    function testOnlyOwnerCanWithdrawRemainingTokens() public {
        vm.prank(user1);
        vm.expectRevert(MerkleAirdrop.NotOwner.selector);
        airdrop.withdrawRemainingTokens();
    }

    function testOwnerCanWithdrawRemainingTokens() public {
        vm.prank(user1);
        airdrop.claim(AMOUNT_USER1, proofUser1);

        uint256 ownerBalanceBefore = token.balanceOf(owner);
        uint256 contractBalanceBefore = token.balanceOf(address(airdrop));

        airdrop.withdrawRemainingTokens();

        assertEq(token.balanceOf(address(airdrop)), 0);
        assertEq(token.balanceOf(owner), ownerBalanceBefore + contractBalanceBefore);
    }

    function hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }
}
