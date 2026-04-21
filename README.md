# Solidity Projects with Foundry

A portfolio of Solidity smart contracts built with **Foundry** as part of my smart contract engineering learning journey.

## Tech Stack
- Solidity
- Foundry
- Forge
- OpenZeppelin

## Projects

- **Savings Contract** — deposit and withdraw ETH
- **Escrow Contract** — simple buyer-seller escrow flow
- **Vesting Contract** — time-based fund release
- **MyToken (ERC-20)** — token contract with minting logic
- **Crowdfunding Contract** — target, deadline, claim, and refund flow
- **Staking Contract** — token staking with reward calculation
- **Voting / DAO Contract** — proposal creation and voting system
- **MultiSig Wallet Contract** — multi-owner transaction approval
- **Marketplace Contract** — item listing and ETH purchase flow
- **Timelock Wallet Contract** — locked funds with delayed withdrawal
- **Auction Contract** — highest-bid auction with refund logic
- **Lottery Contract** — entrance fee, winner selection, and prize payout
- **NFT Collection Contract** — ERC-721 minting with mint fee, max supply, and owner withdrawal

## Project Details

### 1. Savings Contract
Simple ETH savings contract.

**Features:**
- Deposit ETH
- Withdraw ETH
- Store balance per address
- Tests for success and failure cases

**Files:**
- `src/Savings.sol`
- `test/Savings.t.sol`

---

### 2. Escrow Contract
Simple escrow contract between buyer and seller.

**Features:**
- Buyer deposits ETH into the contract
- Funds are held securely in the contract
- Buyer can release funds to seller
- Validation so only buyer can deposit and release

**Files:**
- `src/Escrow.sol`
- `test/Escrow.t.sol`

---

### 3. Vesting Contract
Simple vesting contract for gradual fund release over time.

**Features:**
- Funds are locked at deployment
- Beneficiary receives funds gradually
- Partial release based on elapsed time
- Validation so only beneficiary can release funds

**Files:**
- `src/Vesting.sol`
- `test/Vesting.t.sol`

---

### 4. MyToken (ERC-20)
Simple ERC-20 token contract using OpenZeppelin.

**Features:**
- Initial supply assigned to owner at deployment
- Token transfers to other addresses
- Owner can mint new tokens
- Non-owner cannot mint

**Files:**
- `src/MyToken.sol`
- `test/MyToken.t.sol`

---

### 5. Crowdfunding Contract
Simple crowdfunding contract with funding target and deadline.

**Features:**
- Users can contribute ETH
- Campaign has target and deadline
- Owner can claim funds if target is reached
- Users can refund if target is not reached
- Contributions are tracked per user

**Files:**
- `src/Crowdfunding.sol`
- `test/Crowdfunding.t.sol`

---

### 6. Staking Contract
Simple staking contract using ERC-20 tokens.

**Features:**
- Users can stake tokens
- Staked balances are tracked
- Rewards are calculated based on time
- Users can claim rewards
- Users can unstake tokens

**Files:**
- `src/Staking.sol`
- `test/Staking.t.sol`

---

### 7. Voting / DAO Contract
Simple voting contract for proposals and vote tracking.

**Features:**
- Owner can create proposals
- Users can vote yes or no
- One address can only vote once per proposal
- Proposal can be finalized
- Voting result can be viewed

**Files:**
- `src/Voting.sol`
- `test/Voting.t.sol`

---

### 8. MultiSig Wallet Contract
Simple multi-signature wallet contract with multiple owners.

**Features:**
- Multiple owners
- Submit transaction
- Confirm transaction
- Execute transaction after enough confirmations
- Minimum confirmations set during deployment

**Files:**
- `src/MultiSigWallet.sol`
- `test/MultiSigWallet.t.sol`

---

### 9. Marketplace Contract
Simple marketplace contract for listing and buying items using ETH.

**Features:**
- Seller can create listings
- Buyer can purchase items with ETH
- Item is marked as sold after purchase
- Seller receives payment
- Buyer cannot buy their own item

**Files:**
- `src/Marketplace.sol`
- `test/Marketplace.t.sol`

---

### 10. Timelock Wallet Contract
Simple wallet contract that locks funds until a certain time.

**Features:**
- Funds are locked until unlock time
- Only owner can withdraw
- Contract can receive additional ETH
- Withdraw only after unlock time
- Wallet balance can be checked

**Files:**
- `src/TimelockWallet.sol`
- `test/TimelockWallet.t.sol`

---

### 11. Auction Contract
Simple auction contract for highest-bid bidding flow.

**Features:**
- Users can place bids with ETH
- New bid must be higher than previous bid
- Previous bidder can withdraw refund
- Owner can end auction after deadline
- Winner and highest bid are recorded

**Files:**
- `src/Auction.sol`
- `test/Auction.t.sol`

---

### 12. Lottery Contract
Simple lottery contract where users join by paying an entrance fee and one winner receives the full prize pool.

**Features:**
- Users enter by paying ETH
- Only owner can draw the winner
- Winner receives the full contract balance
- Owner can open or close the lottery
- Players list resets after winner selection

**Files:**
- `src/Lottery.sol`
- `test/Lottery.t.sol`

---

### 13. NFT Collection Contract
Simple ERC-721 collection contract with paid minting, max supply, and owner withdrawal.

**Features:**
- Users can mint NFTs by paying ETH
- Owner can open or close minting
- Each NFT stores its own token URI
- Max supply is enforced
- Owner can withdraw collected ETH

**Files:**
- `src/NFTCollection.sol`
- `test/NFTCollection.t.sol`

---

## Run Locally

```bash
forge build
forge test

What I Practiced
Solidity fundamentals
ETH transfers
access control
mappings and arrays
payable functions
constructors
time-based logic
ERC-20 token mechanics
refund and claim patterns
staking and rewards
governance and voting
multi-signature flow
marketplace logic
auction systems
lottery mechanics
ERC-721 / NFT minting
token URI handling
max supply checks
testing with Foundry
Status
Savings Contract: completed
Escrow Contract: completed
Vesting Contract: completed
MyToken (ERC-20): completed
Crowdfunding Contract: completed
Staking Contract: completed
Voting / DAO Contract: completed
MultiSig Wallet Contract: completed
Marketplace Contract: completed
Timelock Wallet Contract: completed
Auction Contract: completed
Lottery Contract: completed
NFT Collection Contract: completed

All projects completed and tests passing.

Purpose

This repository documents my hands-on progress in smart contract development through practical Solidity projects and testing with Foundry.