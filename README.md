# EquiNVDA Protocol

A DeFi-style synthetic asset protocol that allows users to mint, trade, and redeem synthetic NVDA tokens (EquiNVDA) backed by ETH collateral on Sepolia testnet.

## 🏗️ Architecture

### Core Contracts

#### 1. EquiVault.sol

The main contract managing ETH collateral deposits, synthetic token minting, redemption, and liquidations.

**Key Features:**

- **Collateral Management**: Users deposit ETH as collateral
- **Synthetic Token Minting**: Mint eNVDA tokens based on collateral value with 500% minimum collateral ratio
- **Redemption**: Burn synthetic tokens to redeem ETH collateral
- **Liquidation**: Third-party liquidation of under-collateralized positions
- **Collateralization Rules**:
  - Minimum Collateral Ratio (CR): 500%
  - Liquidation threshold: 130%
  - Liquidation penalty: 10% (reward to liquidator)

#### 2. EquiAsset.sol

ERC20 token contract for EquiNVDA synthetic asset.

**Features:**

- Symbol: `eNVDA`
- Name: `EquiNVDA`
- Mintable and burnable only by the EquiVault contract
- Standard ERC20 functionality

#### 3. ChainlinkOracle.sol

Oracle contract providing price feeds for both ETH/USD and NVDA/USD.

**Features:**

- **ETH/USD Feed**: Real Chainlink price feed on Sepolia (`0x694AA1769357215DE4FAC081bf1f309aDC325306`)
- **NVDA/USD Feed**: Mock price feed (configurable, starts at $450)
- **Price Management**: Owner can update mock NVDA price
- **Price Fluctuation**: Optional simulation of price changes

## 🔧 Oracle Setup

### ETH/USD Feed (Real Chainlink)

- **Address**: `0x694AA1769357215DE4FAC081bf1f309aDC325306`
- **Network**: Sepolia testnet
- **Purpose**: Collateral valuation

### NVDA/USD Feed (Mock Oracle)

- **Initial Price**: $450 (8 decimals)
- **Management**: Owner-controlled price updates
- **Purpose**: Synthetic token valuation

## 💰 Collateral & Minting Logic

### Collateral Ratio Calculation

```
Collateral Ratio = (Collateral Value in USD) / (Debt Value in USD) × 100%

Where:
- Collateral Value = ETH_deposited × ETH/USD_price
- Debt Value = minted_EquiNVDA × NVDA/USD_price
```

### Minting Logic

Instead of minting the requested number of tokens, the contract mints proportionally based on collateral value:

```
mintableAmount = (collateralValueInUSD / NVDA_price) / 5  // for 500% CR
```

### Liquidation Logic

- **Trigger**: When user's CR < 130%
- **Process**: Liquidator repays user's debt in exchange for collateral
- **Reward**: Liquidator receives 10% extra collateral as penalty
- **Remaining**: Any remaining collateral returned to the user

## 🧪 Testing

The protocol includes comprehensive Foundry tests covering:

### Test Coverage

- ✅ Successful mint under 500% CR
- 🚫 Revert on attempted mint beyond 500% CR
- 🔁 Oracle mock price update and correct price fetching
- ⚠️ Liquidation when CR < 130%
- 💰 Correct liquidation penalty and reward distribution
- 🔄 End-to-end flow: Deposit → Mint → Mock price drop → Liquidation → Redemption

### Running Tests

```bash
# Compile contracts
forge build

# Run all tests
forge test

# Run tests with verbose output
forge test -vvv
```

### Test Scenarios

1. **Basic Operations**: Deposit, mint, redeem, withdraw
2. **Collateral Ratio Enforcement**: Tests minimum CR requirements
3. **Liquidation Mechanics**: Price drop scenarios and liquidation execution
4. **Oracle Integration**: Mock price updates and Chainlink feed integration
5. **Edge Cases**: Error conditions and boundary testing

## 🚀 Deployment

### Prerequisites

- Foundry installed
- Sepolia testnet access
- ETH for gas fees

### Deployment Steps

1. **Deploy ChainlinkOracle**:

   ```solidity
   ChainlinkOracle oracle = new ChainlinkOracle(
       ETH_USD_FEED_ADDRESS,  // 0x694AA1769357215DE4FAC081bf1f309aDC325306
       INITIAL_NVDA_PRICE     // 450e8 ($450)
   );
   ```

2. **Deploy EquiAsset**:

   ```solidity
   EquiAsset equiAsset = new EquiAsset();
   ```

3. **Deploy EquiVault**:

   ```solidity
   EquiVault vault = new EquiVault(
       address(equiAsset),
       address(oracle)
   );
   ```

4. **Set Vault in Token Contract**:
   ```solidity
   equiAsset.setVault(address(vault));
   ```

## 📊 Usage Examples

### Basic User Flow

1. **Deposit Collateral**:

   ```solidity
   vault.depositCollateral{value: 1 ether}();
   ```

2. **Mint Synthetic Tokens**:

   ```solidity
   vault.mintEquiNVDA(8e17); // Mint 0.8 eNVDA tokens
   ```

3. **Check Vault Status**:

   ```solidity
   (uint256 collateral, uint256 debt, uint256 ratio, bool exists) = vault.getVaultData(user);
   ```

4. **Redeem Tokens**:

   ```solidity
   vault.redeemCollateral(4e17); // Redeem 0.4 eNVDA tokens
   ```

5. **Withdraw Collateral**:
   ```solidity
   vault.withdrawCollateral(0.5 ether);
   ```

### Liquidation Flow

1. **Check Liquidation Eligibility**:

   ```solidity
   uint256 ratio = vault.getCollateralRatio(user);
   bool liquidatable = ratio < vault.LIQUIDATION_THRESHOLD();
   ```

2. **Execute Liquidation**:
   ```solidity
   vault.liquidate(user);
   ```

## 🔗 Frontend Integration

The protocol is designed to integrate seamlessly with Scaffold-ETH frontend:

### React Hooks Needed

- `depositCollateral()`
- `mintEquiNVDA()`
- `redeemCollateral()`
- `liquidate(address user)`
- `getCollateralRatio(address user)`
- `getLatestPrice()` from both oracles

### Frontend Features

- Real-time NVDA/USD mock price display
- ETH/USD live price (Chainlink)
- User's collateral ratio and vault health
- Liquidation button for vaults <130% CR
- Network: Sepolia (ETH) via MetaMask

## 📈 Economic Model

### Collateralization

- **Minimum CR**: 500% ensures high safety margin
- **Liquidation Threshold**: 130% prevents bad debt
- **Liquidation Penalty**: 10% incentivizes liquidators

### Price Discovery

- **ETH Price**: Real market data via Chainlink
- **NVDA Price**: Synthetic/mock price for testing
- **Risk Management**: Over-collateralization protects against volatility

## 🛡️ Security Features

- **ReentrancyGuard**: Prevents reentrancy attacks
- **Ownable**: Admin controls for oracle management
- **Input Validation**: Comprehensive parameter checking
- **Collateral Ratio Enforcement**: Automatic liquidation triggers
- **Access Control**: Vault-only token minting/burning

## 📝 Contract Addresses (Sepolia)

_Note: These are example addresses - replace with actual deployed addresses_

- **EquiVault**: `0x...`
- **EquiAsset**: `0x...`
- **ChainlinkOracle**: `0x...`
- **ETH/USD Feed**: `0x694AA1769357215DE4FAC081bf1f309aDC325306`

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## ⚠️ Disclaimer

This is a demonstration protocol for educational purposes. The mock NVDA price feed is not connected to real market data and should not be used for actual trading or investment decisions.

---

**Built with ❤️ using Foundry and Scaffold-ETH**
