// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Lottery} from "../src/lottery.sol";

contract LotteryTest is Test {
    Lottery lottery;

    address owner = address(this);
    address player1 = address(0x1);
    address player2 = address(0x2);
    address player3 = address(0x3);

    uint256 constant ENTRANCE_FEE = 1 ether;
    uint256 constant STARTING_BALANCE = 10 ether;

    function setUp() public {
        lottery = new Lottery(ENTRANCE_FEE);

        vm.deal(player1, STARTING_BALANCE);
        vm.deal(player2, STARTING_BALANCE);
        vm.deal(player3, STARTING_BALANCE);
    }

    function testConstructorSetsInitialValues() public view {
        assertEq(lottery.owner(), owner);
        assertEq(lottery.entranceFee(), ENTRANCE_FEE);
        assertTrue(lottery.lotteryOpen());
    }

    function testEnterLotteryRevertsIfFeeTooLow() public {
        vm.prank(player1);
        vm.expectRevert(Lottery.InsufficientEntryFee.selector);
        lottery.enterLottery{value: 0.5 ether}();
    }

    function testEnterLotteryStoresPlayer() public {
        vm.prank(player1);
        lottery.enterLottery{value: ENTRANCE_FEE}();

        assertEq(lottery.getPlayersCount(), 1);
        assertEq(lottery.getPlayers()[0], player1);
    }

    function testCannotEnterWhenLotteryClosed() public {
        lottery.setLotteryOpen(false);

        vm.prank(player1);
        vm.expectRevert(Lottery.LotteryClosed.selector);
        lottery.enterLottery{value: ENTRANCE_FEE}();
    }

    function testOnlyOwnerCanDrawWinner() public {
        vm.prank(player1);
        vm.expectRevert(Lottery.NotOwner.selector);
        lottery.drawWinner();
    }

    function testDrawWinnerRevertsWhenNoPlayers() public {
        vm.expectRevert(Lottery.NoPlayersEntered.selector);
        lottery.drawWinner();
    }

    function testDrawWinnerPaysWinnerAndResetsPlayers() public {
        vm.prank(player1);
        lottery.enterLottery{value: ENTRANCE_FEE}();

        vm.prank(player2);
        lottery.enterLottery{value: ENTRANCE_FEE}();

        vm.prank(player3);
        lottery.enterLottery{value: ENTRANCE_FEE}();

        assertEq(address(lottery).balance, 3 ether);
        assertEq(lottery.getPlayersCount(), 3);

        vm.warp(100);

        lottery.drawWinner();

        address winner = lottery.lastWinner();

        assertTrue(winner == player1 || winner == player2 || winner == player3, "winner must be one of the players");

        assertEq(address(lottery).balance, 0);
        assertEq(lottery.getPlayersCount(), 0);

        assertEq(winner.balance, 12 ether);

        if (winner != player1) assertEq(player1.balance, 9 ether);
        if (winner != player2) assertEq(player2.balance, 9 ether);
        if (winner != player3) assertEq(player3.balance, 9 ether);
    }
}
