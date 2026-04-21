// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Crowdsale} from "../src/Crowdsale.sol";

contract MockSaleToken is ERC20 {
    constructor() ERC20("Mock Sale Token", "MST") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract CrowdsaleTest is Test {
    MockSaleToken token;
    Crowdsale sale;

    address owner = address(this);
    address buyer1 = address(0x1);
    address buyer2 = address(0x2);
    address outsider = address(0x99);

    uint256 constant RATE = 1000;
    uint256 constant DURATION = 7 days;

    uint256 startTime;

    receive() external payable {}

    function setUp() public {
        token = new MockSaleToken();

        startTime = block.timestamp + 1 days;
        sale = new Crowdsale(address(token), RATE, startTime, DURATION);

        token.mint(address(sale), 1_000_000 ether);

        vm.deal(owner, 0);
        vm.deal(buyer1, 10 ether);
        vm.deal(buyer2, 10 ether);
        vm.deal(outsider, 10 ether);
    }

    function testConstructorSetsInitialValues() public view {
        assertEq(sale.owner(), owner);
        assertEq(address(sale.token()), address(token));
        assertEq(sale.rate(), RATE);
        assertEq(sale.startAt(), startTime);
        assertEq(sale.endAt(), startTime + DURATION);
        assertFalse(sale.saleClosed());
    }

    function testBuyRevertsBeforeSaleStarts() public {
        vm.prank(buyer1);
        vm.expectRevert(Crowdsale.SaleNotStarted.selector);
        sale.buyTokens{value: 1 ether}();
    }

    function testBuyRevertsIfZeroEthSent() public {
        vm.warp(startTime);

        vm.prank(buyer1);
        vm.expectRevert(Crowdsale.ZeroEthSent.selector);
        sale.buyTokens{value: 0}();
    }

    function testBuyTransfersTokensAndUpdatesAccounting() public {
        vm.warp(startTime);

        vm.prank(buyer1);
        sale.buyTokens{value: 1 ether}();

        assertEq(token.balanceOf(buyer1), 1000 ether);
        assertEq(sale.purchasedTokens(buyer1), 1000 ether);
        assertEq(sale.totalRaised(), 1 ether);
        assertEq(sale.totalTokensSold(), 1000 ether);
        assertEq(address(sale).balance, 1 ether);
    }

    function testBuyRevertsAfterSaleEnded() public {
        vm.warp(startTime + DURATION);

        vm.prank(buyer1);
        vm.expectRevert(Crowdsale.SaleEnded.selector);
        sale.buyTokens{value: 1 ether}();
    }

    function testBuyRevertsIfSaleClosedByOwner() public {
        vm.prank(owner);
        sale.closeSale();

        vm.warp(startTime);

        vm.prank(buyer1);
        vm.expectRevert(Crowdsale.SaleClosed.selector);
        sale.buyTokens{value: 1 ether}();
    }

    function testBuyRevertsIfContractLacksEnoughTokens() public {
        vm.warp(startTime);

        Crowdsale smallSale = new Crowdsale(address(token), RATE, startTime, DURATION);
        token.mint(address(smallSale), 500 ether);

        vm.deal(buyer1, 10 ether);

        vm.prank(buyer1);
        vm.expectRevert(Crowdsale.InsufficientTokenBalance.selector);
        smallSale.buyTokens{value: 1 ether}();
    }

    function testOnlyOwnerCanCloseSale() public {
        vm.prank(outsider);
        vm.expectRevert(Crowdsale.NotOwner.selector);
        sale.closeSale();
    }

    function testOwnerCanWithdrawEth() public {
        vm.warp(startTime);

        vm.prank(buyer1);
        sale.buyTokens{value: 2 ether}();

        uint256 ownerBalanceBefore = owner.balance;

        sale.withdrawETH();

        assertEq(address(sale).balance, 0);
        assertEq(owner.balance, ownerBalanceBefore + 2 ether);
    }

    function testOnlyOwnerCanWithdrawEth() public {
        vm.warp(startTime);

        vm.prank(buyer1);
        sale.buyTokens{value: 1 ether}();

        vm.prank(outsider);
        vm.expectRevert(Crowdsale.NotOwner.selector);
        sale.withdrawETH();
    }

    function testOwnerCanWithdrawUnsoldTokens() public {
        vm.warp(startTime);

        vm.prank(buyer1);
        sale.buyTokens{value: 1 ether}();

        uint256 ownerTokenBalanceBefore = token.balanceOf(owner);
        uint256 unsoldBalance = token.balanceOf(address(sale));

        sale.withdrawUnsoldTokens();

        assertEq(token.balanceOf(address(sale)), 0);
        assertEq(token.balanceOf(owner), ownerTokenBalanceBefore + unsoldBalance);
    }

    function testOnlyOwnerCanWithdrawUnsoldTokens() public {
        vm.prank(outsider);
        vm.expectRevert(Crowdsale.NotOwner.selector);
        sale.withdrawUnsoldTokens();
    }
}
