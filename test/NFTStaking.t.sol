// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {NFTStaking} from "../src/NFTStaking.sol";

contract MockRewardToken is ERC20 {
    constructor() ERC20("RewardToken", "RWD") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockNFT is ERC721 {
    constructor() ERC721("MockNFT", "MNFT") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

contract NFTStakingTest is Test {
    MockRewardToken rewardToken;
    MockNFT nft;
    NFTStaking staking;

    address owner = address(this);
    address user1 = address(0x1);
    address user2 = address(0x2);
    address outsider = address(0x99);

    uint256 constant REWARD_PER_DAY = 10 ether;

    function setUp() public {
        rewardToken = new MockRewardToken();
        nft = new MockNFT();

        staking = new NFTStaking(address(nft), address(rewardToken), REWARD_PER_DAY);

        rewardToken.mint(address(staking), 1000 ether);

        nft.mint(user1, 1);
        nft.mint(user1, 2);
        nft.mint(user2, 3);

        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }

    function testConstructorSetsInitialValues() public view {
        assertEq(staking.owner(), owner);
        assertEq(address(staking.nftCollection()), address(nft));
        assertEq(address(staking.rewardToken()), address(rewardToken));
        assertEq(staking.rewardPerDay(), REWARD_PER_DAY);
    }

    function testStakeTransfersNFTAndStoresData() public {
        vm.startPrank(user1);
        nft.approve(address(staking), 1);
        staking.stake(1);
        vm.stopPrank();

        assertEq(nft.ownerOf(1), address(staking));
        assertEq(staking.stakerOf(1), user1);
        assertEq(staking.getStakedTokens(user1).length, 1);
        assertEq(staking.getStakedTokens(user1)[0], 1);
    }

    function testStakeRevertsIfCallerIsNotTokenOwner() public {
        vm.prank(user2);
        vm.expectRevert(NFTStaking.NotNFTOwner.selector);
        staking.stake(1);
    }

    function testClaimRewardAfterOneDay() public {
        vm.startPrank(user1);
        nft.approve(address(staking), 1);
        staking.stake(1);
        vm.warp(block.timestamp + 1 days);
        staking.claimReward(1);
        vm.stopPrank();

        assertEq(rewardToken.balanceOf(user1), REWARD_PER_DAY);
        assertEq(staking.pendingReward(1), 0);
    }

    function testClaimRewardRevertsIfNoRewardAvailable() public {
        vm.startPrank(user1);
        nft.approve(address(staking), 1);
        staking.stake(1);
        vm.expectRevert(NFTStaking.NoRewardAvailable.selector);
        staking.claimReward(1);
        vm.stopPrank();
    }

    function testOnlyStakerCanClaimReward() public {
        vm.startPrank(user1);
        nft.approve(address(staking), 1);
        staking.stake(1);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        vm.prank(user2);
        vm.expectRevert(NFTStaking.NotStaker.selector);
        staking.claimReward(1);
    }

    function testUnstakeReturnsNFTAndAutoPaysReward() public {
        vm.startPrank(user1);
        nft.approve(address(staking), 1);
        staking.stake(1);
        vm.warp(block.timestamp + 2 days);
        staking.unstake(1);
        vm.stopPrank();

        assertEq(nft.ownerOf(1), user1);
        assertEq(rewardToken.balanceOf(user1), 20 ether);
        assertEq(staking.stakerOf(1), address(0));
        assertEq(staking.getStakedTokens(user1).length, 0);
    }

    function testOnlyStakerCanUnstake() public {
        vm.startPrank(user1);
        nft.approve(address(staking), 1);
        staking.stake(1);
        vm.stopPrank();

        vm.prank(outsider);
        vm.expectRevert(NFTStaking.NotStaker.selector);
        staking.unstake(1);
    }

    function testMultipleStakesTrackUserTokens() public {
        vm.startPrank(user1);
        nft.approve(address(staking), 1);
        nft.approve(address(staking), 2);
        staking.stake(1);
        staking.stake(2);
        vm.stopPrank();

        uint256[] memory tokens = staking.getStakedTokens(user1);

        assertEq(tokens.length, 2);
        assertEq(tokens[0], 1);
        assertEq(tokens[1], 2);
    }

    function testOwnerCanWithdrawRemainingRewards() public {
        uint256 ownerBalanceBefore = rewardToken.balanceOf(owner);
        uint256 contractBalanceBefore = rewardToken.balanceOf(address(staking));

        staking.withdrawRemainingRewards();

        assertEq(rewardToken.balanceOf(address(staking)), 0);
        assertEq(rewardToken.balanceOf(owner), ownerBalanceBefore + contractBalanceBefore);
    }

    function testNonOwnerCannotWithdrawRemainingRewards() public {
        vm.prank(user1);
        vm.expectRevert(NFTStaking.NotOwner.selector);
        staking.withdrawRemainingRewards();
    }
}
