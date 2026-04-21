// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {LendingPoolBasic} from "../src/LendingPoolBasic.sol";

contract MockLendingToken is ERC20 {
    constructor() ERC20("Mock Lending Token", "MLT") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract LendingPoolBasicTest is Test {
    MockLendingToken token;
    LendingPoolBasic pool;

    address lp1 = address(0x1);
    address lp2 = address(0x2);
    address borrower = address(0x3);
    address outsider = address(0x99);

    uint256 constant ETH_PRICE_IN_TOKENS = 2000 ether;
    uint256 constant COLLATERAL_FACTOR_BPS = 5000; // 50%
    uint256 constant INITIAL_LIQUIDITY = 5000 ether;

    function setUp() public {
        token = new MockLendingToken();
        pool = new LendingPoolBasic(address(token), ETH_PRICE_IN_TOKENS, COLLATERAL_FACTOR_BPS);

        token.mint(lp1, 10000 ether);
        token.mint(lp2, 5000 ether);
        token.mint(borrower, 5000 ether);

        vm.deal(lp1, 10 ether);
        vm.deal(lp2, 10 ether);
        vm.deal(borrower, 10 ether);
        vm.deal(outsider, 10 ether);
    }

    function testConstructorSetsInitialValues() public view {
        assertEq(address(pool.token()), address(token));
        assertEq(pool.ethPriceInTokens(), ETH_PRICE_IN_TOKENS);
        assertEq(pool.collateralFactorBps(), COLLATERAL_FACTOR_BPS);
        assertEq(pool.totalLiquidity(), 0);
        assertEq(pool.totalBorrowed(), 0);
    }

    function testDepositLiquidityTransfersTokensAndUpdatesState() public {
        vm.startPrank(lp1);
        token.approve(address(pool), INITIAL_LIQUIDITY);
        pool.depositLiquidity(INITIAL_LIQUIDITY);
        vm.stopPrank();

        assertEq(pool.liquidityDeposits(lp1), INITIAL_LIQUIDITY);
        assertEq(pool.totalLiquidity(), INITIAL_LIQUIDITY);
        assertEq(token.balanceOf(address(pool)), INITIAL_LIQUIDITY);
        assertEq(token.balanceOf(lp1), 5000 ether);
    }

    function testDepositCollateralUpdatesState() public {
        vm.prank(borrower);
        pool.depositCollateral{value: 1 ether}();

        assertEq(pool.collateralBalance(borrower), 1 ether);
        assertEq(address(pool).balance, 1 ether);
    }

    function testBorrowTransfersTokensAndUpdatesDebt() public {
        vm.startPrank(lp1);
        token.approve(address(pool), INITIAL_LIQUIDITY);
        pool.depositLiquidity(INITIAL_LIQUIDITY);
        vm.stopPrank();

        vm.prank(borrower);
        pool.depositCollateral{value: 1 ether}();

        vm.prank(borrower);
        pool.borrow(1000 ether);

        assertEq(token.balanceOf(borrower), 6000 ether);
        assertEq(pool.debtBalance(borrower), 1000 ether);
        assertEq(pool.totalBorrowed(), 1000 ether);
        assertEq(token.balanceOf(address(pool)), 4000 ether);
    }

    function testBorrowRevertsIfExceedsMaxBorrow() public {
        vm.startPrank(lp1);
        token.approve(address(pool), INITIAL_LIQUIDITY);
        pool.depositLiquidity(INITIAL_LIQUIDITY);
        vm.stopPrank();

        vm.prank(borrower);
        pool.depositCollateral{value: 1 ether}();

        vm.prank(borrower);
        vm.expectRevert(LendingPoolBasic.BorrowExceedsLimit.selector);
        pool.borrow(1001 ether);
    }

    function testRepayReducesDebt() public {
        vm.startPrank(lp1);
        token.approve(address(pool), INITIAL_LIQUIDITY);
        pool.depositLiquidity(INITIAL_LIQUIDITY);
        vm.stopPrank();

        vm.prank(borrower);
        pool.depositCollateral{value: 1 ether}();

        vm.prank(borrower);
        pool.borrow(1000 ether);

        vm.startPrank(borrower);
        token.approve(address(pool), 400 ether);
        pool.repay(400 ether);
        vm.stopPrank();

        assertEq(pool.debtBalance(borrower), 600 ether);
        assertEq(pool.totalBorrowed(), 600 ether);
        assertEq(token.balanceOf(address(pool)), 4400 ether);
    }

    function testWithdrawCollateralRevertsIfPositionWouldBeUndercollateralized() public {
        vm.startPrank(lp1);
        token.approve(address(pool), INITIAL_LIQUIDITY);
        pool.depositLiquidity(INITIAL_LIQUIDITY);
        vm.stopPrank();

        vm.prank(borrower);
        pool.depositCollateral{value: 1 ether}();

        vm.prank(borrower);
        pool.borrow(1000 ether);

        vm.prank(borrower);
        vm.expectRevert(LendingPoolBasic.BorrowExceedsLimit.selector);
        pool.withdrawCollateral(0.1 ether);
    }

    function testFullRepayAllowsCollateralWithdrawal() public {
        vm.startPrank(lp1);
        token.approve(address(pool), INITIAL_LIQUIDITY);
        pool.depositLiquidity(INITIAL_LIQUIDITY);
        vm.stopPrank();

        vm.prank(borrower);
        pool.depositCollateral{value: 1 ether}();

        vm.prank(borrower);
        pool.borrow(1000 ether);

        vm.startPrank(borrower);
        token.approve(address(pool), 1000 ether);
        pool.repay(1000 ether);
        pool.withdrawCollateral(1 ether);
        vm.stopPrank();

        assertEq(pool.debtBalance(borrower), 0);
        assertEq(pool.collateralBalance(borrower), 0);
        assertEq(borrower.balance, 10 ether);
    }

    function testLiquidityProviderCanWithdrawAvailableLiquidity() public {
        vm.startPrank(lp1);
        token.approve(address(pool), INITIAL_LIQUIDITY);
        pool.depositLiquidity(INITIAL_LIQUIDITY);
        vm.stopPrank();

        vm.prank(borrower);
        pool.depositCollateral{value: 1 ether}();

        vm.prank(borrower);
        pool.borrow(1000 ether);

        vm.prank(lp1);
        pool.withdrawLiquidity(4000 ether);

        assertEq(pool.liquidityDeposits(lp1), 1000 ether);
        assertEq(pool.totalLiquidity(), 1000 ether);
        assertEq(token.balanceOf(lp1), 9000 ether);
        assertEq(token.balanceOf(address(pool)), 0);
    }

    function testWithdrawLiquidityRevertsIfPoolLacksAvailableTokens() public {
        vm.startPrank(lp1);
        token.approve(address(pool), INITIAL_LIQUIDITY);
        pool.depositLiquidity(INITIAL_LIQUIDITY);
        vm.stopPrank();

        vm.prank(borrower);
        pool.depositCollateral{value: 1 ether}();

        vm.prank(borrower);
        pool.borrow(1000 ether);

        vm.prank(lp1);
        vm.expectRevert(LendingPoolBasic.NotEnoughLiquidity.selector);
        pool.withdrawLiquidity(4500 ether);
    }
}
