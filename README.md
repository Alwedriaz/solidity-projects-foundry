# Solidity Projects with Foundry

A portfolio of Solidity smart contracts built with **Foundry** as part of my smart contract engineering learning journey.

This repository contains hands-on projects covering core smart contract patterns such as ETH transfers, access control, token mechanics, staking, governance, auctions, lotteries, and NFTs.

## Highlights

- 13 Solidity projects
- Built and tested with **Foundry**
- Covers both **ERC-20** and **ERC-721**
- Includes automated testing with **Forge**
- Organized as a practical learning portfolio

## Tech Stack

- Solidity
- Foundry
- Forge
- OpenZeppelin

## Projects

| No. | Project | Focus |
|---|---|---|
| 1 | Savings Contract | Deposit and withdraw ETH |
| 2 | Escrow Contract | Buyer-seller escrow flow |
| 3 | Vesting Contract | Time-based fund release |
| 4 | MyToken (ERC-20) | Token minting and transfers |
| 5 | Crowdfunding Contract | Target, deadline, claim, and refund |
| 6 | Staking Contract | ERC-20 staking and rewards |
| 7 | Voting / DAO Contract | Proposals and voting |
| 8 | MultiSig Wallet Contract | Multi-owner transaction approval |
| 9 | Marketplace Contract | Listing and buying with ETH |
| 10 | Timelock Wallet Contract | Locked funds with delayed withdrawal |
| 11 | Auction Contract | Highest-bid auction flow |
| 12 | Lottery Contract | Entrance fee, winner selection, prize payout |
| 13 | NFT Collection Contract | ERC-721 minting with mint fee and max supply |

## What I Practiced

- Solidity fundamentals
- ETH transfers
- `msg.sender` and `msg.value`
- mappings and arrays
- access control
- payable functions
- constructors
- time-based logic
- refund and claim patterns
- ERC-20 token mechanics
- staking and reward calculation
- governance and voting systems
- multi-signature transaction flow
- marketplace logic
- auction systems
- lottery mechanics
- ERC-721 / NFT minting
- token URI handling
- max supply checks
- testing with Foundry

## Run Locally

```bash
forge build
forge test

Repository Structure
src/    # smart contracts
test/   # Foundry tests

Status

All projects completed and tests passing.

Purpose

This repository documents my hands-on progress in smart contract development through practical Solidity projects and testing with Foundry.