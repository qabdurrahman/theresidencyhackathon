# EquiNVDA Protocol

A DeFi synthetic asset protocol that allows users to mint, trade, and redeem synthetic NVDA tokens that track NVIDIA's real-world stock price using ETH as collateral and Chainlink price feeds.

## 🏗️ Architecture

### Core Contracts

1. **EquiAsset.sol** - ERC20 token contract representing synthetic NVDA tokens (EquiNVDA)
2. **EquiVault.sol** - Main vault contract managing ETH collateral, minting, redemption, and liquidation
3. **ChainlinkOracle.sol** - Oracle integration with Chainlink NVDA/USD price feed with fallback mock mode

### Key Features

- **Collateral Token**: ETH
- **Minimum Collateral Ratio**: 150% (15000 basis points)
- **Liquidation Threshold**: 130% (13000 basis points)
- **Liquidation Penalty**: 10% (1000 basis points)
- **Real-time Price Feeds**: Chainlink NVDA/USD and ETH/USD aggregators
- **Fallback Oracle**: Mock price mode for testing when Chainlink feeds are unavailable

## 🔧 Core Logic

### Collateralization System

The protocol maintains a minimum collateralization ratio of 150%, meaning users must provide at least $1.50 worth of ETH collateral for every $1.00 of EquiNVDA tokens they want to mint.

### Liquidation Mechanism

When a user's collateral ratio drops below 130%, their position becomes liquidatable. Liquidators can repay the user's debt in exchange for their collateral plus a 10% penalty.

### Price Oracle Integration

- **Primary**: Chainlink NVDA/USD price feed via AggregatorV3Interface
- **Fallback**: Mock price mode for testing and when Chainlink feeds are unavailable
- **Price Validation**: Ensures prices are positive and not stale (max 24 hours old)

## 📋 Contract Functions

### EquiVault Functions

- `depositCollateral()` - Deposit ETH as collateral
- `mintEquiNVDA(uint256 amount)` - Mint EquiNVDA tokens against collateral
- `redeemCollateral(uint256 amount)` - Redeem ETH collateral
- `repayDebt(uint256 amount)` - Repay debt by burning EquiNVDA tokens
- `liquidate(address user, uint256 maxDebtToLiquidate)` - Liquidate under-collateralized positions
- `getCollateralRatio(address user)` - Get user's collateral ratio
- `getLatestPrice()` - Get current NVDA/USD price from oracle
- `getUserPosition(address user)` - Get user's position information
- `getSystemInfo()` - Get system-wide statistics

### EquiAsset Functions

- `mint(address to, uint256 amount)` - Mint tokens (vault only)
- `burn(address from, uint256 amount)` - Burn tokens (vault only)
- Standard ERC20 functions (transfer, approve, etc.)

### ChainlinkOracle Functions

- `getLatestPrice()` - Get price from Chainlink feed
- `getLatestPriceWithFallback()` - Get price with mock fallback
- `updateMockPrice(int256 newPrice)` - Update mock price (owner only)
- `setUseMockPrice(bool useMock)` - Switch between Chainlink and mock mode (owner only)

## 🧪 Testing

The protocol includes comprehensive Foundry tests covering:

- ✅ Successful collateral deposits
- ✅ Successful minting with sufficient collateral
- ✅ Minting failure with insufficient collateral
- ✅ Collateral redemption
- ✅ Debt repayment
- ✅ Liquidation when collateral ratio drops below threshold
- ✅ Oracle price fetching and fallback
- ✅ Full mint → price drop → liquidation → redemption flow
- ✅ Collateral ratio calculations
- ✅ System and user position information
- ✅ Protocol fee and configuration updates
- ✅ Edge cases and error conditions

### Running Tests

```bash
# Navigate to the foundry package
cd residency2/packages/foundry

# Run all tests
forge test -vvv

# Run specific test
forge test --match-test testMintEquiNVDA -vvv

# Run tests with gas reporting
forge test --gas-report
```

## 🚀 Deployment

### Prerequisites

1. Install Foundry:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. Install dependencies:

```bash
cd residency2/packages/foundry
forge install
```

### Compilation

```bash
forge build
```

### Example Test Sequence

1. **Setup**: Deploy contracts with mock price feeds
2. **Deposit**: User deposits 10 ETH as collateral
3. **Mint**: User mints 20 EquiNVDA tokens (requires ~7.5 ETH collateral at 150% ratio)
4. **Price Drop**: ETH price drops from $2000 to $1000
5. **Liquidation**: Position becomes liquidatable (ratio drops below 130%)
6. **Liquidate**: Liquidator repays debt and receives collateral + penalty
7. **Redeem**: User can redeem remaining collateral

## 🔗 Chainlink Integration

### Mainnet Addresses

- **NVDA/USD**: `0x86cF147c8C0F3D7d6e8A9d8C4d8B8A8A8A8A8A8A8` (example - use actual Chainlink address)
- **ETH/USD**: `0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419` (example - use actual Chainlink address)

### Testnet Addresses

For testing, the protocol uses mock price feeds that can be configured with any address. In production, use the appropriate Chainlink aggregator addresses for your target network.

## 📊 Protocol Parameters

| Parameter                | Value    | Description                                   |
| ------------------------ | -------- | --------------------------------------------- |
| Minimum Collateral Ratio | 150%     | Minimum collateral required for minting       |
| Liquidation Threshold    | 130%     | Ratio below which positions can be liquidated |
| Liquidation Penalty      | 10%      | Penalty paid to liquidators                   |
| Price Decimals           | 8        | Chainlink price feed decimals                 |
| Token Decimals           | 18       | EquiNVDA token decimals                       |
| Max Price Staleness      | 24 hours | Maximum age of price data                     |

## 🛡️ Security Features

- **Reentrancy Protection**: All external functions use OpenZeppelin's ReentrancyGuard
- **Price Validation**: Oracle prices are validated for positivity and staleness
- **Access Control**: Critical functions restricted to contract owner
- **Collateral Ratio Checks**: Prevents under-collateralized positions
- **Liquidation Incentives**: 10% penalty ensures liquidators are compensated

## 📈 Economic Model

### For Users

- **Minting**: Deposit ETH collateral to mint EquiNVDA tokens
- **Trading**: Trade EquiNVDA tokens on secondary markets
- **Redemption**: Burn EquiNVDA tokens to redeem ETH collateral

### For Liquidators

- **Liquidation**: Repay debt to receive collateral + 10% penalty
- **Profit**: Earn penalty fees for maintaining system health

### For Protocol

- **Protocol Fees**: Configurable fees (default 0.5%) on operations
- **Fee Recipient**: Designated address receives protocol fees

## 🔄 Integration with Scaffold-ETH

The protocol is designed to integrate seamlessly with Scaffold-ETH frontend:

- **Hooks**: Custom hooks for all vault functions
- **Real-time Data**: Live price feeds and collateral ratios
- **User Interface**: Modern DeFi interface for minting, trading, and liquidation
- **Wallet Integration**: MetaMask and other wallet support

## 📝 License

MIT License - see LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## ⚠️ Disclaimer

This is experimental software. Use at your own risk. The protocol has not been audited and may contain bugs or vulnerabilities. Always test thoroughly before using with real funds.
