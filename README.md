# EquiNVDA Protocol

EquiNVDA is a synthetic asset protocol that lets users mint, trade, and redeem synthetic NVDA tokens (called **eNVDA**) backed by ETH collateral.  
It uses **Foundry** for smart contracts and testing, and **Scaffold-ETH** for the frontend.  
All interactions happen on the **Sepolia testnet**.

---

## Overview

Users can deposit ETH as collateral, mint synthetic eNVDA tokens that track a mock NVDA/USD price, and redeem them later.  
If the value of their collateral drops and their collateral ratio becomes too low, their position can be liquidated by other users.

---

## Core Features

- ETH-backed synthetic NVDA (eNVDA)
- Real Chainlink ETH/USD feed + mock NVDA/USD oracle
- 500% minimum collateral ratio (CR)
- Liquidations triggered below 130% CR
- 10% liquidation reward to liquidators
- Fully tested with Foundry
- Integrated frontend via Scaffold-ETH

---

## Contracts

### 1. EquiVault.sol
Main contract managing:
- Collateral deposits and withdrawals  
- Minting and redeeming eNVDA tokens  
- Liquidations  
- Collateral ratio checks  

**Parameters**
- Minimum CR: 500%  
- Liquidation threshold: 130%  
- Liquidation penalty: 10%  

**Key Functions**
- `depositCollateral()` – deposit ETH  
- `mintEquiNVDA()` – mint eNVDA based on collateral value  
- `redeemCollateral()` – burn eNVDA to withdraw ETH  
- `liquidate(address user)` – liquidate under-collateralized positions  
- `getCollateralRatio(address user)` – view user’s current CR  

---

### 2. EquiAsset.sol
ERC20 token for eNVDA.

- Name: EquiNVDA  
- Symbol: eNVDA  
- Mintable and burnable only by the vault contract  

---

### 3. ChainlinkOracle.sol
Handles price feeds.

- **ETH/USD** uses the real Chainlink feed on Sepolia  
  Address: `0x694AA1769357215DE4FAC081bf1f309aDC325306`  
- **NVDA/USD** is a mock oracle with a manually adjustable price (default around $450)

**Mock Oracle Features**
- Manual updates via `updateMockPrice()`  
- Optional small random fluctuations per block  
- Correct 8-decimal precision  

---

## Collateral and Minting Logic

Collateral value is calculated using the live ETH/USD price from Chainlink.  
Minting is based on maintaining a 500% collateral ratio.

Example formula:
```
collateralValueUSD = ETH_deposited * ETH/USD
mintableAmount = (collateralValueUSD / NVDA_price) / 5
```

A position can be liquidated if the collateral ratio drops below 130%.  
Liquidator pays off the user’s debt and receives collateral +10% bonus.

---

## Testing (Foundry)

All tests are in `/test/EquiVault.t.sol`.

**Test coverage:**
- Minting under correct CR  
- Revert on over-minting  
- Oracle price updates  
- Liquidation when CR < 130%  
- Correct liquidation rewards  
- Full flow: deposit → mint → price drop → liquidation → redemption  

**Commands:**
```
forge build
forge test -vvv
```

---

## Frontend (Scaffold-ETH)

Frontend connects to the contracts on Sepolia using MetaMask.  
It allows users to:
- Deposit collateral  
- Mint and redeem eNVDA  
- View collateral ratio and vault health  
- Liquidate under-collateralized users  

Displayed data includes:
- Real-time ETH/USD and mock NVDA/USD prices  
- User’s collateral ratio  
- Vault status indicators  

---

## Oracle Setup on Sepolia

| Feed | Source | Notes |
|------|---------|-------|
| ETH/USD | Chainlink | Real feed: `0x694AA1769357215DE4FAC081bf1f309aDC325306` |
| NVDA/USD | Mock Oracle | Adjustable manually |

---

## Deployed Contracts (Sepolia)

All deployed to the Sepolia testnet:

- **ChainlinkOracle (mock NVDA/USD)**  
  Address: `0x80A697C81894CFf34702E50819Ef8627C59f679A`

- **EquiAsset (eNVDA token)**  
  Address: `0x150881a3d45acEC4760099E666015FbEEf4690C5`

- **EquiVault (vault & core logic)**  
  Address: `0xC9B4D81b82B03539be906E3E214E277b91677906`

---

## Example Flow

1. User deposits 1 ETH (~$3,000)  
2. NVDA mock price = $450 → Mintable = (3000 / 450) / 5 = 1.33 eNVDA  
3. ETH price drops, CR < 130%  
4. Another user liquidates and earns 10% collateral bonus  
5. Original user redeems remaining ETH by burning tokens  

---

## Deliverables

- `/src/EquiVault.sol` – main vault logic  
- `/src/EquiAsset.sol` – ERC20 eNVDA token  
- `/src/ChainlinkOracle.sol` – price feed integration  
- `/test/EquiVault.t.sol` – Foundry tests  
- `README.md` – documentation  

---

## Tech Stack

- Solidity (Foundry)  
- React (Scaffold-ETH)  
- Chainlink Oracles  
- Sepolia Testnet  
- MetaMask Wallet  

---

## License

MIT License © 2025 EquiNVDA Protocol
