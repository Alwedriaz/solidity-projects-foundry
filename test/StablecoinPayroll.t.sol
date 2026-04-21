// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {StablecoinPayroll} from "../src/StablecoinPayroll.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract StablecoinPayrollTest is Test {
    MockUSDC usdc;
    StablecoinPayroll payroll;

    address owner = address(this);
    address financeManager = address(0xF1);
    address alice = address(0x1);
    address bob = address(0x2);
    address outsider = address(0x99);

    uint256 constant PERIOD_DURATION = 30 days;
    uint256 constant ALICE_PAY = 1_000e6;
    uint256 constant BOB_PAY = 2_000e6;

    uint256 startTime;

    function setUp() public {
        usdc = new MockUSDC();

        startTime = block.timestamp + 1 days;
        payroll = new StablecoinPayroll(address(usdc), startTime, PERIOD_DURATION);

        usdc.mint(owner, 100_000e6);
        usdc.approve(address(payroll), type(uint256).max);
    }

    function testConstructorSetsInitialValues() public view {
        assertEq(payroll.owner(), owner);
        assertEq(address(payroll.stablecoin()), address(usdc));
        assertEq(payroll.startTime(), startTime);
        assertEq(payroll.periodDuration(), PERIOD_DURATION);
        assertEq(payroll.financeManager(), address(0));
        assertFalse(payroll.paused());
        assertEq(payroll.totalClaimed(), 0);
    }

    function testOnlyOwnerCanSetFinanceManager() public {
        vm.prank(outsider);
        vm.expectRevert(StablecoinPayroll.NotOwner.selector);
        payroll.setFinanceManager(financeManager);

        payroll.setFinanceManager(financeManager);
        assertEq(payroll.financeManager(), financeManager);
    }

    function testOnlyOwnerCanPausePayroll() public {
        vm.prank(outsider);
        vm.expectRevert(StablecoinPayroll.NotOwner.selector);
        payroll.setPaused(true);

        payroll.setPaused(true);
        assertTrue(payroll.paused());

        payroll.setPaused(false);
        assertFalse(payroll.paused());
    }

    function testFinanceManagerCanManageRecipients() public {
        payroll.setFinanceManager(financeManager);

        vm.prank(financeManager);
        payroll.addRecipient(alice, ALICE_PAY);

        (uint256 amountPerPeriod, bool active, uint256 lastClaimedPeriod, bool exists) = payroll.recipients(alice);

        assertEq(amountPerPeriod, ALICE_PAY);
        assertTrue(active);
        assertEq(lastClaimedPeriod, 0);
        assertTrue(exists);

        vm.prank(financeManager);
        payroll.updateRecipientAmount(alice, 1_500e6);

        vm.prank(financeManager);
        payroll.setRecipientActive(alice, false);

        (amountPerPeriod, active,, exists) = payroll.recipients(alice);

        assertEq(amountPerPeriod, 1_500e6);
        assertFalse(active);
        assertTrue(exists);
    }

    function testNonAdminCannotManageRecipients() public {
        vm.prank(outsider);
        vm.expectRevert(StablecoinPayroll.NotAdmin.selector);
        payroll.addRecipient(alice, ALICE_PAY);
    }

    function testFinanceManagerCannotWithdrawTreasury() public {
        payroll.setFinanceManager(financeManager);
        payroll.depositTreasury(10_000e6);

        vm.prank(financeManager);
        vm.expectRevert(StablecoinPayroll.NotOwner.selector);
        payroll.withdrawTreasury(1_000e6);
    }

    function testRecipientCanClaimOncePerPeriod() public {
        payroll.depositTreasury(10_000e6);
        payroll.addRecipient(alice, ALICE_PAY);

        vm.warp(startTime);

        vm.prank(alice);
        payroll.claim();

        assertEq(usdc.balanceOf(alice), ALICE_PAY);
        assertEq(payroll.totalClaimed(), ALICE_PAY);

        (,, uint256 lastClaimedPeriod,) = payroll.recipients(alice);
        assertEq(lastClaimedPeriod, 1);

        vm.prank(alice);
        vm.expectRevert(StablecoinPayroll.AlreadyClaimedForCurrentPeriod.selector);
        payroll.claim();
    }

    function testClaimRevertsWhenPayrollPaused() public {
        payroll.depositTreasury(10_000e6);
        payroll.addRecipient(alice, ALICE_PAY);
        payroll.setPaused(true);

        vm.warp(startTime);

        vm.prank(alice);
        vm.expectRevert(StablecoinPayroll.PayrollPaused.selector);
        payroll.claim();
    }

    function testClaimWorksAgainAfterUnpause() public {
        payroll.depositTreasury(10_000e6);
        payroll.addRecipient(alice, ALICE_PAY);
        payroll.setPaused(true);

        vm.warp(startTime);

        payroll.setPaused(false);

        vm.prank(alice);
        payroll.claim();

        assertEq(usdc.balanceOf(alice), ALICE_PAY);
    }

    function testClaimRevertsIfRecipientInactive() public {
        payroll.depositTreasury(10_000e6);
        payroll.addRecipient(alice, ALICE_PAY);
        payroll.setRecipientActive(alice, false);

        vm.warp(startTime);

        vm.prank(alice);
        vm.expectRevert(StablecoinPayroll.RecipientInactive.selector);
        payroll.claim();
    }

    function testUpdateRecipientAmountChangesFutureClaims() public {
        payroll.depositTreasury(10_000e6);
        payroll.addRecipient(alice, ALICE_PAY);

        vm.warp(startTime);

        vm.prank(alice);
        payroll.claim();

        payroll.updateRecipientAmount(alice, 1_500e6);

        vm.warp(startTime + PERIOD_DURATION);

        vm.prank(alice);
        payroll.claim();

        assertEq(usdc.balanceOf(alice), 2_500e6);
    }

    function testMultipleRecipientsClaimIndependently() public {
        payroll.depositTreasury(10_000e6);
        payroll.addRecipient(alice, ALICE_PAY);
        payroll.addRecipient(bob, BOB_PAY);

        vm.warp(startTime);

        vm.prank(alice);
        payroll.claim();

        vm.prank(bob);
        payroll.claim();

        assertEq(usdc.balanceOf(alice), ALICE_PAY);
        assertEq(usdc.balanceOf(bob), BOB_PAY);
        assertEq(payroll.totalClaimed(), ALICE_PAY + BOB_PAY);
        assertEq(usdc.balanceOf(address(payroll)), 7_000e6);
    }

    function testOwnerCanWithdrawTreasury() public {
        payroll.depositTreasury(10_000e6);
        payroll.addRecipient(alice, ALICE_PAY);

        vm.warp(startTime);

        vm.prank(alice);
        payroll.claim();

        uint256 ownerBalanceBefore = usdc.balanceOf(owner);

        payroll.withdrawTreasury(3_000e6);

        assertEq(usdc.balanceOf(owner), ownerBalanceBefore + 3_000e6);
        assertEq(usdc.balanceOf(address(payroll)), 6_000e6);
    }
}
