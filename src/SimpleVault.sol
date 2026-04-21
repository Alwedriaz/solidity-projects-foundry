// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SimpleVault is ERC20 {
    error ZeroAmount();
    error ZeroShares();
    error TransferFailed();

    IERC20 public immutable asset;

    event Deposited(address indexed user, uint256 assets, uint256 shares);
    event Redeemed(address indexed user, uint256 shares, uint256 assets);

    constructor(address _asset) ERC20("Vault Share", "VSH") {
        asset = IERC20(_asset);
    }

    function deposit(uint256 assets) external returns (uint256 shares) {
        if (assets == 0) revert ZeroAmount();

        uint256 assetsBefore = totalAssets();
        uint256 supply = totalSupply();

        bool success = asset.transferFrom(msg.sender, address(this), assets);
        if (!success) revert TransferFailed();

        if (supply == 0 || assetsBefore == 0) {
            shares = assets;
        } else {
            shares = (assets * supply) / assetsBefore;
        }

        if (shares == 0) revert ZeroShares();

        _mint(msg.sender, shares);

        emit Deposited(msg.sender, assets, shares);
    }

    function redeem(uint256 shares) external returns (uint256 assets) {
        if (shares == 0) revert ZeroAmount();

        assets = previewRedeem(shares);
        if (assets == 0) revert ZeroAmount();

        _burn(msg.sender, shares);

        bool success = asset.transfer(msg.sender, assets);
        if (!success) revert TransferFailed();

        emit Redeemed(msg.sender, shares, assets);
    }

    function previewDeposit(uint256 assets) public view returns (uint256 shares) {
        if (assets == 0) return 0;

        uint256 supply = totalSupply();
        uint256 assetsInVault = totalAssets();

        if (supply == 0 || assetsInVault == 0) {
            return assets;
        }

        return (assets * supply) / assetsInVault;
    }

    function previewRedeem(uint256 shares) public view returns (uint256 assets) {
        if (shares == 0) return 0;

        uint256 supply = totalSupply();
        uint256 assetsInVault = totalAssets();

        if (supply == 0) {
            return 0;
        }

        return (shares * assetsInVault) / supply;
    }

    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function getVaultAssetBalance() external view returns (uint256) {
        return asset.balanceOf(address(this));
    }
}
