// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract NFTStaking is ERC721Holder {
    error NotOwner();
    error NotNFTOwner();
    error NotStaker();
    error NoRewardAvailable();
    error InvalidAddress();
    error InvalidRewardRate();
    error RewardTransferFailed();

    address public immutable owner;
    IERC721 public immutable nftCollection;
    IERC20 public immutable rewardToken;
    uint256 public immutable rewardPerDay;

    mapping(uint256 => address) public stakerOf;
    mapping(uint256 => uint256) public stakedAt;
    mapping(uint256 => uint256) public lastClaimedAt;

    mapping(address => uint256[]) private stakedTokensByUser;
    mapping(uint256 => uint256) private stakedTokenIndex;

    event Staked(address indexed user, uint256 indexed tokenId);
    event RewardClaimed(address indexed user, uint256 indexed tokenId, uint256 amount);
    event Unstaked(address indexed user, uint256 indexed tokenId, uint256 reward);
    event RewardWithdrawn(address indexed owner, uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address _nftCollection, address _rewardToken, uint256 _rewardPerDay) {
        if (_nftCollection == address(0) || _rewardToken == address(0)) revert InvalidAddress();
        if (_rewardPerDay == 0) revert InvalidRewardRate();

        owner = msg.sender;
        nftCollection = IERC721(_nftCollection);
        rewardToken = IERC20(_rewardToken);
        rewardPerDay = _rewardPerDay;
    }

    function stake(uint256 tokenId) external {
        if (nftCollection.ownerOf(tokenId) != msg.sender) revert NotNFTOwner();

        nftCollection.safeTransferFrom(msg.sender, address(this), tokenId);

        stakerOf[tokenId] = msg.sender;
        stakedAt[tokenId] = block.timestamp;
        lastClaimedAt[tokenId] = block.timestamp;

        _addStakedToken(msg.sender, tokenId);

        emit Staked(msg.sender, tokenId);
    }

    function claimReward(uint256 tokenId) external {
        address staker = stakerOf[tokenId];
        if (staker == address(0)) revert NotStaker();
        if (staker != msg.sender) revert NotStaker();

        uint256 reward = pendingReward(tokenId);
        if (reward == 0) revert NoRewardAvailable();

        lastClaimedAt[tokenId] = block.timestamp;

        bool success = rewardToken.transfer(msg.sender, reward);
        if (!success) revert RewardTransferFailed();

        emit RewardClaimed(msg.sender, tokenId, reward);
    }

    function unstake(uint256 tokenId) external {
        address staker = stakerOf[tokenId];
        if (staker == address(0)) revert NotStaker();
        if (staker != msg.sender) revert NotStaker();

        uint256 reward = pendingReward(tokenId);

        _removeStakedToken(msg.sender, tokenId);

        delete stakerOf[tokenId];
        delete stakedAt[tokenId];
        delete lastClaimedAt[tokenId];

        if (reward > 0) {
            bool successReward = rewardToken.transfer(msg.sender, reward);
            if (!successReward) revert RewardTransferFailed();
        }

        nftCollection.safeTransferFrom(address(this), msg.sender, tokenId);

        emit Unstaked(msg.sender, tokenId, reward);
    }

    function pendingReward(uint256 tokenId) public view returns (uint256) {
        if (stakerOf[tokenId] == address(0)) {
            return 0;
        }

        uint256 elapsed = block.timestamp - lastClaimedAt[tokenId];
        return (elapsed * rewardPerDay) / 1 days;
    }

    function getStakedTokens(address user) external view returns (uint256[] memory) {
        return stakedTokensByUser[user];
    }

    function getContractRewardBalance() external view returns (uint256) {
        return rewardToken.balanceOf(address(this));
    }

    function withdrawRemainingRewards() external onlyOwner {
        uint256 balance = rewardToken.balanceOf(address(this));

        bool success = rewardToken.transfer(owner, balance);
        if (!success) revert RewardTransferFailed();

        emit RewardWithdrawn(owner, balance);
    }

    function _addStakedToken(address user, uint256 tokenId) internal {
        stakedTokenIndex[tokenId] = stakedTokensByUser[user].length;
        stakedTokensByUser[user].push(tokenId);
    }

    function _removeStakedToken(address user, uint256 tokenId) internal {
        uint256 lastIndex = stakedTokensByUser[user].length - 1;
        uint256 index = stakedTokenIndex[tokenId];

        if (index != lastIndex) {
            uint256 lastTokenId = stakedTokensByUser[user][lastIndex];
            stakedTokensByUser[user][index] = lastTokenId;
            stakedTokenIndex[lastTokenId] = index;
        }

        stakedTokensByUser[user].pop();
        delete stakedTokenIndex[tokenId];
    }
}
