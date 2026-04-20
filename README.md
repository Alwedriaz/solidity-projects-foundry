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

## Cara Menjalankan

```bash
forge build
forge test