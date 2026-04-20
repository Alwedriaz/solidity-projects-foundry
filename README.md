# Solidity Projects with Foundry

Kumpulan smart contract sederhana menggunakan Solidity dan Foundry sebagai bagian dari portfolio belajar smart contract engineering.

## Project di dalam Repo

### 1. Savings Contract
Smart contract tabungan sederhana.

**Fitur:**
- Deposit ETH
- Withdraw ETH
- Simpan saldo per address
- Test untuk kondisi berhasil dan gagal

**File:**
- `src/Savings.sol`
- `test/Savings.t.sol`

---

### 2. Escrow Contract
Smart contract escrow sederhana antara buyer dan seller.

**Fitur:**
- Buyer deposit ETH ke contract
- Dana ditahan di contract
- Buyer bisa release dana ke seller
- Validasi agar hanya buyer yang bisa deposit dan release

**File:**
- `src/Escrow.sol`
- `test/Escrow.t.sol`

---

### 3. Vesting Contract
Smart contract vesting sederhana untuk pelepasan dana bertahap berdasarkan waktu.

**Fitur:**
- Dana dikunci saat deploy
- Beneficiary menerima dana secara bertahap
- Release sebagian dana sesuai waktu yang sudah berjalan
- Validasi agar hanya beneficiary yang bisa release

**File:**
- `src/Vesting.sol`
- `test/Vesting.t.sol`

---

### 4. MyToken (ERC-20)
Smart contract token sederhana menggunakan OpenZeppelin.

**Fitur:**
- Initial supply diberikan ke owner saat deploy
- Transfer token ke address lain
- Owner bisa mint token baru
- Non-owner tidak boleh mint

**File:**
- `src/MyToken.sol`
- `test/MyToken.t.sol`

---

### 5. Crowdfunding Contract
Smart contract crowdfunding sederhana dengan target dana dan deadline.

**Fitur:**
- User bisa berkontribusi ETH
- Campaign punya target dan deadline
- Owner bisa claim dana jika target tercapai
- User bisa refund jika target tidak tercapai
- Kontribusi tiap user tercatat

**File:**
- `src/Crowdfunding.sol`
- `test/Crowdfunding.t.sol`

---

### 6. Staking Contract
Smart contract staking sederhana menggunakan token ERC-20.

**Fitur:**
- User bisa stake token
- Saldo stake per user tercatat
- Reward dihitung berdasarkan waktu
- User bisa claim reward
- User bisa unstake token

**File:**
- `src/Staking.sol`
- `test/Staking.t.sol`

## Cara Menjalankan

```bash
forge build
forge test
```

## Yang Dipelajari
- Solidity dasar
- mapping
- address
- msg.sender
- msg.value
- payable
- require
- constructor
- block.timestamp
- escrow logic
- vesting logic
- ERC-20
- Ownable
- mint
- transfer
- OpenZeppelin
- crowdfunding logic
- deadline
- refund
- claim funds
- staking logic
- reward calculation
- approve
- transferFrom
- claim reward
- unstake
- testing dengan Foundry

## Status
- Savings Contract: selesai
- Escrow Contract: selesai
- Vesting Contract: selesai
- MyToken (ERC-20): selesai
- Crowdfunding Contract: selesai
- Staking Contract: selesai

Semua test lulus.