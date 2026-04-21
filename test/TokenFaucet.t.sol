// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {TokenFaucet} from "../src/TokenFaucet.sol";

contract MockFaucetToken is ERC20 {
    constructor() ERC20("Mock Faucet Token", "MFT") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract TokenFaucetTest is Test {
    MockFaucetToken token;
    TokenFaucet faucet;

    address owner = address(this);
    address user1 = address(0x1);
    address user2 = address(0x2);
    address outsider = address(0x99);

    uint256 constant FAUCET_AMOUNT = 100 ether;
    uint256 constant COOLDOWN = 1 days;

    function setUp() public {
        token = new MockFaucetToken();
        faucet = new TokenFaucet(address(token), FAUCET_AMOUNT, COOLDOWN);

        token.mint(address(faucet), 1000 ether);
    }

    function testConstructorSetsInitialValues() public view {
        assertEq(faucet.owner(), owner);
        assertEq(address(faucet.token()), address(token));
        assertEq(faucet.faucetAmount(), FAUCET_AMOUNT);
        assertEq(faucet.cooldown(), COOLDOWN);
    }

    function testClaimTransfersTokensAndUpdatesTimestamp() public {
        vm.prank(user1);
        faucet.claim();

        assertEq(token.balanceOf(user1), FAUCET_AMOUNT);
        assertEq(faucet.lastClaimedAt(user1), block.timestamp);
        assertEq(token.balanceOf(address(faucet)), 900 ether);
    }

    function testClaimRevertsIfCalledTooSoon() public {
        vm.startPrank(user1);
        faucet.claim();

        vm.expectRevert(TokenFaucet.ClaimTooSoon.selector);
        faucet.claim();
        vm.stopPrank();
    }

    function testClaimWorksAgainAfterCooldown() public {
        vm.prank(user1);
        faucet.claim();

        vm.warp(block.timestamp + COOLDOWN + 1);

        vm.prank(user1);
        faucet.claim();

        assertEq(token.balanceOf(user1), 200 ether);
        assertEq(token.balanceOf(address(faucet)), 800 ether);
    }

    function testDifferentUsersCanClaimIndependently() public {
        vm.prank(user1);
        faucet.claim();

        vm.prank(user2);
        faucet.claim();

        assertEq(token.balanceOf(user1), FAUCET_AMOUNT);
        assertEq(token.balanceOf(user2), FAUCET_AMOUNT);
        assertEq(token.balanceOf(address(faucet)), 800 ether);
    }

    function testClaimRevertsIfFaucetHasInsufficientBalance() public {
        MockFaucetToken smallToken = new MockFaucetToken();
        TokenFaucet smallFaucet = new TokenFaucet(address(smallToken), FAUCET_AMOUNT, COOLDOWN);

        smallToken.mint(address(smallFaucet), 50 ether);

        vm.prank(user1);
        vm.expectRevert(TokenFaucet.InsufficientFaucetBalance.selector);
        smallFaucet.claim();
    }

    function testOnlyOwnerCanWithdrawRemainingTokens() public {
        vm.prank(outsider);
        vm.expectRevert(TokenFaucet.NotOwner.selector);
        faucet.withdrawRemainingTokens();
    }

    function testOwnerCanWithdrawRemainingTokens() public {
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        uint256 contractBalanceBefore = token.balanceOf(address(faucet));

        faucet.withdrawRemainingTokens();

        assertEq(token.balanceOf(address(faucet)), 0);
        assertEq(token.balanceOf(owner), ownerBalanceBefore + contractBalanceBefore);
    }

    function testCanClaimReturnsExpectedValue() public {
        assertTrue(faucet.canClaim(user1));

        vm.prank(user1);
        faucet.claim();

        assertFalse(faucet.canClaim(user1));

        vm.warp(block.timestamp + COOLDOWN + 1);

        assertTrue(faucet.canClaim(user1));
    }
}
