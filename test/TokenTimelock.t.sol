// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {TokenTimelock} from "../src/TokenTimelock.sol";

contract MockLockToken is ERC20 {
    constructor() ERC20("Mock Lock Token", "MLT") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract TokenTimelockTest is Test {
    MockLockToken token;
    TokenTimelock timelock;

    address owner = address(this);
    address beneficiary = address(0x1);
    address outsider = address(0x99);

    uint256 constant INITIAL_SUPPLY = 1000 ether;
    uint256 constant DEPOSIT_1 = 100 ether;
    uint256 constant DEPOSIT_2 = 50 ether;

    uint256 unlockAt;

    function setUp() public {
        token = new MockLockToken();

        unlockAt = block.timestamp + 30 days;
        timelock = new TokenTimelock(address(token), beneficiary, unlockAt);

        token.mint(owner, INITIAL_SUPPLY);
        token.approve(address(timelock), INITIAL_SUPPLY);
    }

    function testConstructorSetsInitialValues() public view {
        assertEq(timelock.owner(), owner);
        assertEq(address(timelock.token()), address(token));
        assertEq(timelock.beneficiary(), beneficiary);
        assertEq(timelock.unlockTime(), unlockAt);
        assertEq(timelock.totalLocked(), 0);
        assertEq(timelock.totalReleased(), 0);
    }

    function testOnlyOwnerCanDeposit() public {
        vm.prank(outsider);
        vm.expectRevert(TokenTimelock.NotOwner.selector);
        timelock.deposit(DEPOSIT_1);
    }

    function testDepositRevertsIfZeroAmount() public {
        vm.expectRevert(TokenTimelock.ZeroAmount.selector);
        timelock.deposit(0);
    }

    function testDepositTransfersTokensAndUpdatesAccounting() public {
        timelock.deposit(DEPOSIT_1);

        assertEq(token.balanceOf(address(timelock)), DEPOSIT_1);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - DEPOSIT_1);
        assertEq(timelock.totalLocked(), DEPOSIT_1);
        assertEq(timelock.getContractTokenBalance(), DEPOSIT_1);
    }

    function testDepositRevertsAfterUnlockTime() public {
        vm.warp(unlockAt);

        vm.expectRevert(TokenTimelock.TimelockExpired.selector);
        timelock.deposit(DEPOSIT_1);
    }

    function testOnlyBeneficiaryCanRelease() public {
        timelock.deposit(DEPOSIT_1);

        vm.warp(unlockAt);

        vm.prank(outsider);
        vm.expectRevert(TokenTimelock.NotBeneficiary.selector);
        timelock.release();
    }

    function testReleaseRevertsBeforeUnlock() public {
        timelock.deposit(DEPOSIT_1);

        vm.prank(beneficiary);
        vm.expectRevert(TokenTimelock.UnlockTimeNotReached.selector);
        timelock.release();
    }

    function testReleaseTransfersTokensToBeneficiary() public {
        timelock.deposit(DEPOSIT_1);

        vm.warp(unlockAt);

        vm.prank(beneficiary);
        timelock.release();

        assertEq(token.balanceOf(beneficiary), DEPOSIT_1);
        assertEq(token.balanceOf(address(timelock)), 0);
        assertEq(timelock.totalReleased(), DEPOSIT_1);
    }

    function testMultipleDepositsAreReleasedTogether() public {
        timelock.deposit(DEPOSIT_1);
        timelock.deposit(DEPOSIT_2);

        vm.warp(unlockAt + 1);

        vm.prank(beneficiary);
        timelock.release();

        assertEq(token.balanceOf(beneficiary), DEPOSIT_1 + DEPOSIT_2);
        assertEq(token.balanceOf(address(timelock)), 0);
        assertEq(timelock.totalLocked(), DEPOSIT_1 + DEPOSIT_2);
        assertEq(timelock.totalReleased(), DEPOSIT_1 + DEPOSIT_2);
    }

    function testReleaseRevertsIfNothingToRelease() public {
        vm.warp(unlockAt);

        vm.prank(beneficiary);
        vm.expectRevert(TokenTimelock.NothingToRelease.selector);
        timelock.release();
    }
}
