// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {TokenLaunchManager} from "../src/TokenLaunchManager.sol";

contract MockPaymentToken is ERC20 {
    constructor() ERC20("Mock Payment Token", "MPT") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockSaleToken is ERC20 {
    constructor() ERC20("Mock Sale Token", "MST") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract TokenLaunchManagerTest is Test {
    MockPaymentToken paymentToken;
    MockSaleToken saleToken;
    TokenLaunchManager launch;

    address owner = address(this);
    address operator = address(0xAA);
    address alice = address(0x1);
    address bob = address(0x2);
    address outsider = address(0x99);

    uint256 constant TOKEN_RATE = 2e18; // 2 sale tokens per 1 payment token
    uint256 constant INITIAL_UNLOCK_BPS = 2000; // 20%
    uint256 constant VESTING_DURATION = 100 days;

    uint256 saleStart;
    uint256 saleEnd;

    function setUp() public {
        paymentToken = new MockPaymentToken();
        saleToken = new MockSaleToken();

        saleStart = block.timestamp + 1 days;
        saleEnd = saleStart + 7 days;

        launch = new TokenLaunchManager(
            address(saleToken),
            address(paymentToken),
            saleStart,
            saleEnd,
            TOKEN_RATE,
            INITIAL_UNLOCK_BPS,
            VESTING_DURATION
        );

        paymentToken.mint(alice, 10_000 ether);
        paymentToken.mint(bob, 10_000 ether);

        saleToken.mint(address(launch), 1_000_000 ether);

        vm.startPrank(alice);
        paymentToken.approve(address(launch), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        paymentToken.approve(address(launch), type(uint256).max);
        vm.stopPrank();
    }

    function testConstructorSetsInitialValues() public view {
        assertEq(launch.owner(), owner);
        assertEq(address(launch.saleToken()), address(saleToken));
        assertEq(address(launch.paymentToken()), address(paymentToken));
        assertEq(launch.saleStart(), saleStart);
        assertEq(launch.saleEnd(), saleEnd);
        assertEq(launch.tokenRate(), TOKEN_RATE);
        assertEq(launch.initialUnlockBps(), INITIAL_UNLOCK_BPS);
        assertEq(launch.vestingDuration(), VESTING_DURATION);
        assertEq(launch.launchOperator(), address(0));
        assertFalse(launch.finalized());
        assertFalse(launch.cancelled());
        assertFalse(launch.buyPaused());
        assertFalse(launch.claimPaused());
    }

    function testOnlyOwnerCanSetLaunchOperator() public {
        vm.prank(outsider);
        vm.expectRevert(TokenLaunchManager.NotOwner.selector);
        launch.setLaunchOperator(operator);

        launch.setLaunchOperator(operator);
        assertEq(launch.launchOperator(), operator);
    }

    function testOnlyAdminCanSetAllocation() public {
        vm.prank(outsider);
        vm.expectRevert(TokenLaunchManager.NotAdmin.selector);
        launch.setAllocation(alice, 100 ether);
    }

    function testOwnerCanSetAllocation() public {
        launch.setAllocation(alice, 100 ether);
        assertEq(launch.allocation(alice), 100 ether);
    }

    function testOperatorCanSetAllocation() public {
        launch.setLaunchOperator(operator);

        vm.prank(operator);
        launch.setAllocation(alice, 100 ether);

        assertEq(launch.allocation(alice), 100 ether);
    }

    function testBatchSetAllocationWorks() public {
        launch.setLaunchOperator(operator);

        address[] memory users = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        users[0] = alice;
        users[1] = bob;
        amounts[0] = 100 ether;
        amounts[1] = 200 ether;

        vm.prank(operator);
        launch.batchSetAllocation(users, amounts);

        assertEq(launch.allocation(alice), 100 ether);
        assertEq(launch.allocation(bob), 200 ether);
    }

    function testBatchSetAllocationRevertsIfLengthMismatch() public {
        launch.setLaunchOperator(operator);

        address[] memory users = new address[](2);
        uint256[] memory amounts = new uint256[](1);

        users[0] = alice;
        users[1] = bob;
        amounts[0] = 100 ether;

        vm.prank(operator);
        vm.expectRevert(TokenLaunchManager.ArrayLengthMismatch.selector);
        launch.batchSetAllocation(users, amounts);
    }

    function testOnlyAdminCanPauseBuyAndClaim() public {
        vm.prank(outsider);
        vm.expectRevert(TokenLaunchManager.NotAdmin.selector);
        launch.setBuyPaused(true);

        vm.prank(outsider);
        vm.expectRevert(TokenLaunchManager.NotAdmin.selector);
        launch.setClaimPaused(true);
    }

    function testOperatorCanPauseBuyAndClaim() public {
        launch.setLaunchOperator(operator);

        vm.prank(operator);
        launch.setBuyPaused(true);
        assertTrue(launch.buyPaused());

        vm.prank(operator);
        launch.setClaimPaused(true);
        assertTrue(launch.claimPaused());
    }

    function testBuyRevertsBeforeSaleStart() public {
        launch.setAllocation(alice, 100 ether);

        vm.prank(alice);
        vm.expectRevert(TokenLaunchManager.SaleNotStarted.selector);
        launch.buy(100 ether);
    }

    function testBuyRevertsWhenBuyPaused() public {
        launch.setAllocation(alice, 100 ether);
        launch.setBuyPaused(true);

        vm.warp(saleStart);

        vm.prank(alice);
        vm.expectRevert(TokenLaunchManager.BuyPaused.selector);
        launch.buy(100 ether);
    }

    function testBuyRevertsIfExceedsAllocation() public {
        launch.setAllocation(alice, 100 ether);

        vm.warp(saleStart);

        vm.prank(alice);
        vm.expectRevert(TokenLaunchManager.ExceedsAllocation.selector);
        launch.buy(101 ether);
    }

    function testBuyUpdatesAccountingCorrectly() public {
        launch.setAllocation(alice, 100 ether);

        vm.warp(saleStart);

        vm.prank(alice);
        launch.buy(100 ether);

        assertEq(launch.purchasedPayment(alice), 100 ether);
        assertEq(launch.purchasedTokenAmount(alice), 200 ether);
        assertEq(launch.totalRaised(), 100 ether);
        assertEq(launch.totalTokensSold(), 200 ether);
        assertEq(paymentToken.balanceOf(address(launch)), 100 ether);
    }

    function testClaimRevertsBeforeFinalize() public {
        launch.setAllocation(alice, 100 ether);

        vm.warp(saleStart);

        vm.prank(alice);
        launch.buy(100 ether);

        vm.prank(alice);
        vm.expectRevert(TokenLaunchManager.SaleNotFinalized.selector);
        launch.claim();
    }

    function testFinalizeSaleAfterSaleEnd() public {
        vm.warp(saleEnd);

        launch.finalizeSale();

        assertTrue(launch.finalized());
        assertEq(launch.finalizedAt(), saleEnd);
    }

    function testClaimRevertsWhenClaimPaused() public {
        launch.setAllocation(alice, 100 ether);

        vm.warp(saleStart);
        vm.prank(alice);
        launch.buy(100 ether);

        vm.warp(saleEnd);
        launch.finalizeSale();
        launch.setClaimPaused(true);

        vm.prank(alice);
        vm.expectRevert(TokenLaunchManager.ClaimPaused.selector);
        launch.claim();
    }

    function testInitialClaimAfterFinalizeWorks() public {
        launch.setAllocation(alice, 100 ether);

        vm.warp(saleStart);
        vm.prank(alice);
        launch.buy(100 ether);

        vm.warp(saleEnd);
        launch.finalizeSale();

        vm.prank(alice);
        launch.claim();

        assertEq(saleToken.balanceOf(alice), 40 ether);
        assertEq(launch.claimedTokens(alice), 40 ether);
    }

    function testSecondImmediateClaimReverts() public {
        launch.setAllocation(alice, 100 ether);

        vm.warp(saleStart);
        vm.prank(alice);
        launch.buy(100 ether);

        vm.warp(saleEnd);
        launch.finalizeSale();

        vm.prank(alice);
        launch.claim();

        vm.prank(alice);
        vm.expectRevert(TokenLaunchManager.NothingToClaim.selector);
        launch.claim();
    }

    function testClaimWorksAsVestingProgresses() public {
        launch.setAllocation(alice, 100 ether);

        vm.warp(saleStart);
        vm.prank(alice);
        launch.buy(100 ether);

        vm.warp(saleEnd);
        launch.finalizeSale();

        vm.prank(alice);
        launch.claim();

        vm.warp(saleEnd + 50 days);

        vm.prank(alice);
        launch.claim();

        assertEq(saleToken.balanceOf(alice), 120 ether);
        assertEq(launch.claimedTokens(alice), 120 ether);
    }

    function testFinalClaimAfterFullVesting() public {
        launch.setAllocation(alice, 100 ether);

        vm.warp(saleStart);
        vm.prank(alice);
        launch.buy(100 ether);

        vm.warp(saleEnd);
        launch.finalizeSale();

        vm.prank(alice);
        launch.claim();

        vm.warp(saleEnd + 100 days);

        vm.prank(alice);
        launch.claim();

        assertEq(saleToken.balanceOf(alice), 200 ether);
        assertEq(launch.claimedTokens(alice), 200 ether);
        assertEq(launch.claimableAmount(alice), 0);
    }

    function testRefundWorksIfSaleCancelled() public {
        launch.setAllocation(alice, 100 ether);

        vm.warp(saleStart);
        vm.prank(alice);
        launch.buy(100 ether);

        launch.cancelSale();

        uint256 aliceBalanceBefore = paymentToken.balanceOf(alice);

        vm.prank(alice);
        launch.refund();

        assertEq(paymentToken.balanceOf(alice), aliceBalanceBefore + 100 ether);
        assertEq(launch.purchasedPayment(alice), 0);
        assertTrue(launch.refunded(alice));
    }

    function testCannotRefundTwice() public {
        launch.setAllocation(alice, 100 ether);

        vm.warp(saleStart);
        vm.prank(alice);
        launch.buy(100 ether);

        launch.cancelSale();

        vm.prank(alice);
        launch.refund();

        vm.prank(alice);
        vm.expectRevert(TokenLaunchManager.AlreadyRefunded.selector);
        launch.refund();
    }

    function testRefundRevertsIfSaleNotCancelled() public {
        launch.setAllocation(alice, 100 ether);

        vm.warp(saleStart);
        vm.prank(alice);
        launch.buy(100 ether);

        vm.prank(alice);
        vm.expectRevert(TokenLaunchManager.RefundNotAvailable.selector);
        launch.refund();
    }

    function testWithdrawRaisedFundsRevertsBeforeFinalize() public {
        launch.setAllocation(alice, 100 ether);

        vm.warp(saleStart);
        vm.prank(alice);
        launch.buy(100 ether);

        vm.expectRevert(TokenLaunchManager.WithdrawalNotAvailable.selector);
        launch.withdrawRaisedFunds(100 ether);
    }

    function testOwnerCanWithdrawRaisedFundsAfterFinalize() public {
        launch.setAllocation(alice, 100 ether);

        vm.warp(saleStart);
        vm.prank(alice);
        launch.buy(100 ether);

        vm.warp(saleEnd);
        launch.finalizeSale();

        uint256 ownerBalanceBefore = paymentToken.balanceOf(owner);

        launch.withdrawRaisedFunds(100 ether);

        assertEq(paymentToken.balanceOf(owner), ownerBalanceBefore + 100 ether);
        assertEq(paymentToken.balanceOf(address(launch)), 0);
        assertEq(launch.totalPaymentWithdrawn(), 100 ether);
    }

    function testNonOwnerCannotWithdrawRaisedFunds() public {
        launch.setAllocation(alice, 100 ether);

        vm.warp(saleStart);
        vm.prank(alice);
        launch.buy(100 ether);

        vm.warp(saleEnd);
        launch.finalizeSale();

        vm.prank(outsider);
        vm.expectRevert(TokenLaunchManager.NotOwner.selector);
        launch.withdrawRaisedFunds(100 ether);
    }

    function testWithdrawUnsoldSaleTokensRevertsBeforeFinalizeOrCancel() public {
        vm.expectRevert(TokenLaunchManager.WithdrawalNotAvailable.selector);
        launch.withdrawUnsoldSaleTokens(1 ether);
    }

    function testOwnerCanWithdrawUnsoldSaleTokensAfterFinalizeAndKeepClaimBuffer() public {
        launch.setAllocation(alice, 100 ether);

        vm.warp(saleStart);
        vm.prank(alice);
        launch.buy(100 ether);

        vm.warp(saleEnd);
        launch.finalizeSale();

        uint256 availableUnsold = launch.availableUnsoldSaleTokens();
        assertEq(availableUnsold, 999_800 ether);

        launch.withdrawUnsoldSaleTokens(availableUnsold);

        assertEq(saleToken.balanceOf(address(launch)), 200 ether);
        assertEq(launch.totalUnsoldWithdrawn(), 999_800 ether);

        vm.prank(alice);
        launch.claim();

        assertEq(saleToken.balanceOf(alice), 40 ether);

        vm.warp(saleEnd + 100 days);

        vm.prank(alice);
        launch.claim();

        assertEq(saleToken.balanceOf(alice), 200 ether);
    }

    function testOwnerCanWithdrawAllSaleTokensAfterCancellation() public {
        launch.setAllocation(alice, 100 ether);

        vm.warp(saleStart);
        vm.prank(alice);
        launch.buy(100 ether);

        launch.cancelSale();

        uint256 saleTokenBalanceBefore = saleToken.balanceOf(owner);
        uint256 contractSaleTokenBalance = saleToken.balanceOf(address(launch));

        launch.withdrawUnsoldSaleTokens(contractSaleTokenBalance);

        assertEq(saleToken.balanceOf(owner), saleTokenBalanceBefore + contractSaleTokenBalance);
        assertEq(saleToken.balanceOf(address(launch)), 0);
    }

    function testRaisedFundsCannotBeWithdrawnAfterCancellation() public {
        launch.setAllocation(alice, 100 ether);

        vm.warp(saleStart);
        vm.prank(alice);
        launch.buy(100 ether);

        launch.cancelSale();

        vm.expectRevert(TokenLaunchManager.WithdrawalNotAvailable.selector);
        launch.withdrawRaisedFunds(100 ether);
    }
}
