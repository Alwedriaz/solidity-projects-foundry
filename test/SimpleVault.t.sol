// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SimpleVault} from "../src/SimpleVault.sol";

contract MockAssetToken is ERC20 {
    constructor() ERC20("Mock Asset", "MA") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract SimpleVaultTest is Test {
    MockAssetToken asset;
    SimpleVault vault;

    address user1 = address(0x1);
    address user2 = address(0x2);

    function setUp() public {
        asset = new MockAssetToken();
        vault = new SimpleVault(address(asset));

        asset.mint(user1, 1000 ether);
        asset.mint(user2, 1000 ether);
    }

    function testConstructorSetsAsset() public view {
        assertEq(address(vault.asset()), address(asset));
        assertEq(vault.name(), "Vault Share");
        assertEq(vault.symbol(), "VSH");
    }

    function testFirstDepositMintsEqualShares() public {
        vm.startPrank(user1);
        asset.approve(address(vault), 100 ether);
        uint256 shares = vault.deposit(100 ether);
        vm.stopPrank();

        assertEq(shares, 100 ether);
        assertEq(vault.balanceOf(user1), 100 ether);
        assertEq(vault.totalAssets(), 100 ether);
        assertEq(asset.balanceOf(address(vault)), 100 ether);
    }

    function testSecondDepositAfterYieldMintsFewerShares() public {
        vm.startPrank(user1);
        asset.approve(address(vault), 100 ether);
        vault.deposit(100 ether);
        vm.stopPrank();

        asset.mint(address(vault), 100 ether);

        vm.startPrank(user2);
        asset.approve(address(vault), 100 ether);
        uint256 shares = vault.deposit(100 ether);
        vm.stopPrank();

        assertEq(shares, 50 ether);
        assertEq(vault.balanceOf(user2), 50 ether);
        assertEq(vault.totalSupply(), 150 ether);
        assertEq(vault.totalAssets(), 300 ether);
    }

    function testRedeemReturnsProportionalAssets() public {
        vm.startPrank(user1);
        asset.approve(address(vault), 100 ether);
        vault.deposit(100 ether);
        vm.stopPrank();

        asset.mint(address(vault), 100 ether);

        vm.startPrank(user2);
        asset.approve(address(vault), 100 ether);
        vault.deposit(100 ether);
        vm.stopPrank();

        vm.prank(user1);
        uint256 assetsReturned = vault.redeem(100 ether);

        assertEq(assetsReturned, 200 ether);
        assertEq(asset.balanceOf(user1), 1100 ether);
        assertEq(vault.balanceOf(user1), 0);
        assertEq(vault.totalAssets(), 100 ether);
    }

    function testPreviewFunctionsWork() public {
        vm.startPrank(user1);
        asset.approve(address(vault), 100 ether);
        vault.deposit(100 ether);
        vm.stopPrank();

        asset.mint(address(vault), 100 ether);

        assertEq(vault.previewDeposit(100 ether), 50 ether);
        assertEq(vault.previewRedeem(100 ether), 200 ether);
    }

    function testDepositRevertsIfZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(SimpleVault.ZeroAmount.selector);
        vault.deposit(0);
    }

    function testRedeemRevertsIfZeroShares() public {
        vm.prank(user1);
        vm.expectRevert(SimpleVault.ZeroAmount.selector);
        vault.redeem(0);
    }

    function testMultipleUsersCanDepositAndRedeem() public {
        vm.startPrank(user1);
        asset.approve(address(vault), 200 ether);
        vault.deposit(200 ether);
        vm.stopPrank();

        vm.startPrank(user2);
        asset.approve(address(vault), 100 ether);
        vault.deposit(100 ether);
        vm.stopPrank();

        assertEq(vault.totalAssets(), 300 ether);
        assertEq(vault.totalSupply(), 300 ether);

        vm.prank(user2);
        vault.redeem(100 ether);

        assertEq(asset.balanceOf(user2), 1000 ether);
        assertEq(vault.totalAssets(), 200 ether);
        assertEq(vault.totalSupply(), 200 ether);
    }
}
