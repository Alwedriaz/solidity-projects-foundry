# Solidity Projects with Foundry

A portfolio of Solidity smart contracts built with **Foundry** as part of my smart contract engineering learning journey.

This repository contains hands-on projects covering core smart contract patterns such as ETH transfers, access control, token mechanics, staking, governance, auctions, lotteries, NFTs, Merkle-based token distribution, treasury management, vault logic, escrow systems, crowdsales, timelocks, and lending.

## Highlights

- 30 Solidity projects
- Built and tested with **Foundry**
- Covers both **ERC-20** and **ERC-721**
- Includes automated testing with **Forge**
- Organized as a practical smart contract portfolio

## Featured Hands-On Case Study

### Stablecoin Payroll Manager

A product-style smart contract case study for recurring stablecoin payroll distribution to contributors.

**What it demonstrates:**
- recurring stablecoin payroll claims
- finance manager operational role
- pause control for payroll safety
- accrual of missed periods
- no backpay for newly added recipients
- inactive recipients can still claim previously accrued balance
- batch recipient management for real operational workflows

This case study was built as a more realistic, product-oriented smart contract system rather than a single isolated practice contract.

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
| 12 | Lottery Contract | Entrance fee, winner selection, and prize payout |
| 13 | NFT Collection Contract | ERC-721 minting with mint fee and max supply |
| 14 | Merkle Airdrop Contract | Merkle proof-based ERC-20 token claiming |
| 15 | Payment Splitter Contract | Split ETH payouts by predefined shares |
| 16 | Dutch Auction Contract | Time-based decreasing-price auction |
| 17 | NFT Staking Contract | Stake NFTs to earn ERC-20 rewards |
| 18 | Advanced Token Vesting Contract | Cliff, duration, release, and revocable vesting |
| 19 | DAO Treasury Contract | Member proposals, approvals, and treasury execution |
| 20 | Simple Vault Contract | Deposit assets and receive proportional vault shares |
| 21 | ERC20 Staking Pool | Stake ERC-20 tokens to earn rewards over time |
| 22 | Token Faucet Contract | Claim tokens with cooldown-based access |
| 23 | Whitelist NFT Mint | Merkle proof-based whitelist NFT minting |
| 24 | Yield Farming Contract | LP staking with reward-per-share accounting |
| 25 | Governance Snapshot Voting | Snapshot-based voting with quorum and proposal finalization |
| 26 | Crowdsale Contract | Buy ERC-20 tokens with ETH during a timed sale |
| 27 | Escrow Milestone Contract | Milestone-based escrow release and refund flow |
| 28 | Token Timelock Contract | Lock ERC-20 tokens until a future unlock time |
| 29 | MultiSig Treasury Advanced | Multi-owner treasury with confirmations and transaction execution |
| 30 | Lending Pool Basic | Deposit liquidity, borrow against collateral, and repay debt |

## What I Practiced

- Solidity fundamentals
- `msg.sender` and `msg.value`
- ETH transfers
- mappings and arrays
- access control
- payable functions
- constructors
- time-based logic
- refund and claim patterns
- ERC-20 token mechanics
- ERC-721 / NFT minting
- token URI handling
- max supply checks
- staking and reward calculation
- governance and voting systems
- multi-signature transaction flow
- marketplace logic
- auction systems
- lottery mechanics
- Merkle proof verification
- whitelist-based token distribution
- payment splitting by shares
- Dutch auction pricing
- NFT staking rewards
- advanced vesting schedules
- DAO treasury proposal flow
- vault share accounting
- ERC-20 staking pool accounting
- faucet cooldown mechanisms
- whitelist NFT minting with Merkle proofs
- yield farming reward-per-share accounting
- governance snapshot voting
- quorum-based proposal finalization
- crowdsale token distribution
- milestone-based escrow flows
- token timelock patterns
- advanced multisig treasury execution
- lending and collateral logic
- testing with Foundry

## Run Locally

```bash
forge build
forge test
```

## Repository Structure

```bash
src/    # smart contracts
test/   # Foundry tests
```

## Status

All 30 projects completed and tests passing.

## Purpose

This repository documents my hands-on progress in smart contract development through practical Solidity projects and testing with Foundry.