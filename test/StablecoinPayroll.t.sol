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
    address carol = address(0x3);
    address outsider = address(0x99);

    uint256 constant PERIOD_DURATION = 30 days;
    uint256 constant ALICE_PAY = 1_000e6;
    uint256 constant BOB_PAY = 2_000e6;
    uint256 constant CAROL_PAY = 1_500e6;

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

    function testFinanceManagerCanManageRecipients() public {
        payroll.setFinanceManager(financeManager);

        vm.prank(financeManager);
        payroll.addRecipient(alice, ALICE_PAY);

        (
            uint256 amountPerPeriod,
            bool active,
            uint256 lastAccruedPeriod,
            uint256 startPeriod,
            uint256 accruedBalance,
            bool exists
        ) = payroll.recipients(alice);

        assertEq(amountPerPeriod, ALICE_PAY);
        assertTrue(active);
        assertEq(lastAccruedPeriod, 0);
        assertEq(startPeriod, 1);
        assertEq(accruedBalance, 0);
        assertTrue(exists);

        vm.prank(financeManager);
        payroll.updateRecipientAmount(alice, 1_500e6);

        vm.prank(financeManager);
        payroll.setRecipientActive(alice, false);

        (amountPerPeriod, active,,, accruedBalance, exists) = payroll.recipients(alice);

        assertEq(amountPerPeriod, 1_500e6);
        assertFalse(active);
        assertEq(accruedBalance, 0);
        assertTrue(exists);
    }

    function testBatchAddRecipientsWorks() public {
        payroll.setFinanceManager(financeManager);

        address[] memory recipientAddresses = new address[](3);
        uint256[] memory amounts = new uint256[](3);

        recipientAddresses[0] = alice;
        recipientAddresses[1] = bob;
        recipientAddresses[2] = carol;

        amounts[0] = ALICE_PAY;
        amounts[1] = BOB_PAY;
        amounts[2] = CAROL_PAY;

        vm.prank(financeManager);
        payroll.batchAddRecipients(recipientAddresses, amounts);

        (uint256 aliceAmount, bool aliceActive,, uint256 aliceStartPeriod,, bool aliceExists) =
            payroll.recipients(alice);
        (uint256 bobAmount, bool bobActive,, uint256 bobStartPeriod,, bool bobExists) = payroll.recipients(bob);
        (uint256 carolAmount, bool carolActive,, uint256 carolStartPeriod,, bool carolExists) =
            payroll.recipients(carol);

        assertEq(aliceAmount, ALICE_PAY);
        assertEq(bobAmount, BOB_PAY);
        assertEq(carolAmount, CAROL_PAY);

        assertTrue(aliceActive);
        assertTrue(bobActive);
        assertTrue(carolActive);

        assertEq(aliceStartPeriod, 1);
        assertEq(bobStartPeriod, 1);
        assertEq(carolStartPeriod, 1);

        assertTrue(aliceExists);
        assertTrue(bobExists);
        assertTrue(carolExists);
    }

    function testBatchAddRecipientsRevertsIfLengthMismatch() public {
        payroll.setFinanceManager(financeManager);

        address[] memory recipientAddresses = new address[](2);
        uint256[] memory amounts = new uint256[](1);

        recipientAddresses[0] = alice;
        recipientAddresses[1] = bob;
        amounts[0] = ALICE_PAY;

        vm.prank(financeManager);
        vm.expectRevert(StablecoinPayroll.ArrayLengthMismatch.selector);
        payroll.batchAddRecipients(recipientAddresses, amounts);
    }

    function testBatchUpdateRecipientAmountsWorks() public {
        payroll.setFinanceManager(financeManager);

        address[] memory recipientAddresses = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        recipientAddresses[0] = alice;
        recipientAddresses[1] = bob;

        amounts[0] = ALICE_PAY;
        amounts[1] = BOB_PAY;

        vm.prank(financeManager);
        payroll.batchAddRecipients(recipientAddresses, amounts);

        uint256[] memory newAmounts = new uint256[](2);
        newAmounts[0] = 1_500e6;
        newAmounts[1] = 2_500e6;

        vm.prank(financeManager);
        payroll.batchUpdateRecipientAmounts(recipientAddresses, newAmounts);

        (uint256 aliceAmount,,,,,) = payroll.recipients(alice);
        (uint256 bobAmount,,,,,) = payroll.recipients(bob);

        assertEq(aliceAmount, 1_500e6);
        assertEq(bobAmount, 2_500e6);
    }

    function testBatchDeactivateRecipientsPreservesAccruedBalance() public {
        payroll.depositTreasury(20_000e6);
        payroll.setFinanceManager(financeManager);

        address[] memory recipientAddresses = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        recipientAddresses[0] = alice;
        recipientAddresses[1] = bob;

        amounts[0] = ALICE_PAY;
        amounts[1] = BOB_PAY;

        vm.prank(financeManager);
        payroll.batchAddRecipients(recipientAddresses, amounts);

        vm.warp(startTime + PERIOD_DURATION + 1);

        bool[] memory statuses = new bool[](2);
        statuses[0] = false;
        statuses[1] = false;

        vm.prank(financeManager);
        payroll.batchSetRecipientActive(recipientAddresses, statuses);

        (, bool aliceActive, uint256 aliceLastAccrued,, uint256 aliceAccrued,) = payroll.recipients(alice);
        (, bool bobActive, uint256 bobLastAccrued,, uint256 bobAccrued,) = payroll.recipients(bob);

        assertFalse(aliceActive);
        assertFalse(bobActive);

        assertEq(aliceLastAccrued, 2);
        assertEq(bobLastAccrued, 2);

        assertEq(aliceAccrued, 2 * ALICE_PAY);
        assertEq(bobAccrued, 2 * BOB_PAY);

        vm.prank(alice);
        payroll.claim();

        assertEq(usdc.balanceOf(alice), 2 * ALICE_PAY);
    }

    function testNonAdminCannotManageRecipients() public {
        vm.prank(outsider);
        vm.expectRevert(StablecoinPayroll.NotAdmin.selector);
        payroll.addRecipient(alice, ALICE_PAY);
    }

    function testRecipientCanClaimCurrentPeriod() public {
        payroll.depositTreasury(10_000e6);
        payroll.addRecipient(alice, ALICE_PAY);

        vm.warp(startTime);

        vm.prank(alice);
        payroll.claim();

        assertEq(usdc.balanceOf(alice), ALICE_PAY);
        assertEq(payroll.totalClaimed(), ALICE_PAY);

        (,, uint256 lastAccruedPeriod,, uint256 accruedBalance,) = payroll.recipients(alice);
        assertEq(lastAccruedPeriod, 1);
        assertEq(accruedBalance, 0);

        vm.prank(alice);
        vm.expectRevert(StablecoinPayroll.NothingToClaim.selector);
        payroll.claim();
    }

    function testRecipientCanClaimMissedPeriodsAtOnce() public {
        payroll.depositTreasury(10_000e6);
        payroll.addRecipient(alice, ALICE_PAY);

        vm.warp(startTime + PERIOD_DURATION + 1);

        vm.prank(alice);
        payroll.claim();

        assertEq(usdc.balanceOf(alice), 2 * ALICE_PAY);
        assertEq(payroll.totalClaimed(), 2 * ALICE_PAY);
    }

    function testRecipientAddedMidstreamDoesNotGetBackpay() public {
        payroll.depositTreasury(10_000e6);

        vm.warp(startTime + PERIOD_DURATION + 1);

        payroll.addRecipient(alice, ALICE_PAY);

        (,,, uint256 startPeriod,,) = payroll.recipients(alice);
        assertEq(startPeriod, 2);

        vm.prank(alice);
        payroll.claim();

        assertEq(usdc.balanceOf(alice), ALICE_PAY);
        assertEq(payroll.totalClaimed(), ALICE_PAY);
    }

    function testPausedPayrollBlocksClaim() public {
        payroll.depositTreasury(10_000e6);
        payroll.addRecipient(alice, ALICE_PAY);
        payroll.setPaused(true);

        vm.warp(startTime);

        vm.prank(alice);
        vm.expectRevert(StablecoinPayroll.PayrollPaused.selector);
        payroll.claim();
    }

    function testInactiveRecipientCanStillClaimAccruedBalance() public {
        payroll.depositTreasury(10_000e6);
        payroll.addRecipient(alice, ALICE_PAY);

        vm.warp(startTime + PERIOD_DURATION + 1);

        payroll.setRecipientActive(alice, false);

        (, bool active, uint256 lastAccruedPeriod,, uint256 accruedBalance,) = payroll.recipients(alice);
        assertFalse(active);
        assertEq(lastAccruedPeriod, 2);
        assertEq(accruedBalance, 2 * ALICE_PAY);

        vm.prank(alice);
        payroll.claim();

        assertEq(usdc.balanceOf(alice), 2 * ALICE_PAY);

        vm.warp(startTime + (2 * PERIOD_DURATION) + 1);

        vm.prank(alice);
        vm.expectRevert(StablecoinPayroll.NothingToClaim.selector);
        payroll.claim();
    }

    function testUpdateAmountOnlyAffectsFutureAccrual() public {
        payroll.depositTreasury(10_000e6);
        payroll.addRecipient(alice, ALICE_PAY);

        vm.warp(startTime);

        vm.prank(alice);
        payroll.claim();

        vm.warp(startTime + PERIOD_DURATION + 1);

        payroll.updateRecipientAmount(alice, 1_500e6);

        vm.prank(alice);
        payroll.claim();

        assertEq(usdc.balanceOf(alice), 2_000e6);

        vm.warp(startTime + (2 * PERIOD_DURATION) + 1);

        vm.prank(alice);
        payroll.claim();

        assertEq(usdc.balanceOf(alice), 3_500e6);
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

    function testFinanceManagerCannotWithdrawTreasury() public {
        payroll.setFinanceManager(financeManager);
        payroll.depositTreasury(10_000e6);

        vm.prank(financeManager);
        vm.expectRevert(StablecoinPayroll.NotOwner.selector);
        payroll.withdrawTreasury(1_000e6);
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
