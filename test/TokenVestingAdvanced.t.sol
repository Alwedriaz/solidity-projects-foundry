// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {TokenVestingAdvanced} from "../src/TokenVestingAdvanced.sol";

contract MockVestingToken is ERC20 {
    constructor() ERC20("MockVestingToken", "MVT") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract TokenVestingAdvancedTest is Test {
    MockVestingToken token;
    TokenVestingAdvanced vesting;

    address owner = address(this);
    address beneficiary = address(0x1);
    address outsider = address(0x99);

    uint256 constant TOTAL_ALLOCATION = 1000 ether;
    uint256 constant CLIFF_DURATION = 30 days;
    uint256 constant DURATION = 180 days;

    uint256 startTime;

    function setUp() public {
        token = new MockVestingToken();

        startTime = block.timestamp + 1 days;

        vesting = new TokenVestingAdvanced(
            address(token), beneficiary, TOTAL_ALLOCATION, startTime, CLIFF_DURATION, DURATION, true
        );

        token.mint(address(this), TOTAL_ALLOCATION);
        token.transfer(address(vesting), TOTAL_ALLOCATION);
    }

    function testConstructorSetsInitialValues() public view {
        assertEq(vesting.owner(), owner);
        assertEq(address(vesting.token()), address(token));
        assertEq(vesting.beneficiary(), beneficiary);
        assertEq(vesting.totalAllocation(), TOTAL_ALLOCATION);
        assertEq(vesting.start(), startTime);
        assertEq(vesting.cliff(), startTime + CLIFF_DURATION);
        assertEq(vesting.duration(), DURATION);
        assertTrue(vesting.revocable());
    }

    function testOnlyBeneficiaryCanRelease() public {
        vm.prank(outsider);
        vm.expectRevert(TokenVestingAdvanced.NotBeneficiary.selector);
        vesting.release();
    }

    function testReleaseRevertsBeforeCliff() public {
        vm.warp(startTime + 10 days);

        vm.prank(beneficiary);
        vm.expectRevert(TokenVestingAdvanced.NothingToRelease.selector);
        vesting.release();
    }

    function testReleaseTransfersPartialVestedAmount() public {
        vm.warp(startTime + 90 days);

        vm.prank(beneficiary);
        vesting.release();

        assertEq(token.balanceOf(beneficiary), 500 ether);
        assertEq(vesting.released(), 500 ether);
        assertEq(vesting.releasableAmount(), 0);
    }

    function testMultipleReleasesKeepAccountingCorrect() public {
        vm.warp(startTime + 90 days);

        vm.prank(beneficiary);
        vesting.release();

        assertEq(token.balanceOf(beneficiary), 500 ether);

        vm.warp(startTime + 180 days);

        vm.prank(beneficiary);
        vesting.release();

        assertEq(token.balanceOf(beneficiary), 1000 ether);
        assertEq(vesting.released(), 1000 ether);
        assertEq(token.balanceOf(address(vesting)), 0);
    }

    function testOwnerCanRevokeAndBeneficiaryCanStillClaimVestedPart() public {
        vm.warp(startTime + 90 days);

        uint256 ownerBalanceBefore = token.balanceOf(owner);

        vesting.revoke();

        assertTrue(vesting.revoked());
        assertEq(token.balanceOf(owner), ownerBalanceBefore + 500 ether);
        assertEq(token.balanceOf(address(vesting)), 500 ether);

        vm.prank(beneficiary);
        vesting.release();

        assertEq(token.balanceOf(beneficiary), 500 ether);
        assertEq(token.balanceOf(address(vesting)), 0);
    }

    function testNonOwnerCannotRevoke() public {
        vm.prank(outsider);
        vm.expectRevert(TokenVestingAdvanced.NotOwner.selector);
        vesting.revoke();
    }

    function testCannotRevokeTwice() public {
        vesting.revoke();

        vm.expectRevert(TokenVestingAdvanced.AlreadyRevoked.selector);
        vesting.revoke();
    }

    function testVestedAmountIsZeroBeforeCliff() public {
        vm.warp(startTime + 5 days);
        assertEq(vesting.vestedAmount(block.timestamp), 0);
    }

    function testVestedAmountIsFullAfterDuration() public {
        vm.warp(startTime + DURATION);
        assertEq(vesting.vestedAmount(block.timestamp), TOTAL_ALLOCATION);
    }
}
