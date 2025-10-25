//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./EquiAsset.sol";
import "./ChainlinkOracle.sol";

/**
 * @title EquiVault
 * @dev Core contract managing ETH collateral, synthetic token minting, and liquidations
 * @author EquiNVDA Protocol
 */
contract EquiVault is ReentrancyGuard, Ownable {
    // Constants
    uint256 public constant MIN_COLLATERAL_RATIO = 500; // 500% = 5x
    uint256 public constant LIQUIDATION_THRESHOLD = 130; // 130% = 1.3x
    uint256 public constant LIQUIDATION_PENALTY = 10; // 10% penalty
    uint256 public constant PRECISION = 100; // For percentage calculations

    // Contract dependencies
    EquiAsset public immutable equiAsset;
    ChainlinkOracle public immutable oracle;

    // User vault data
    struct VaultData {
        uint256 collateralBalance; // ETH deposited
        uint256 debtAmount; // eNVDA tokens minted
        bool exists; // Whether user has an active vault
    }

    mapping(address => VaultData) public vaults;

    // Global state
    uint256 public totalCollateral;
    uint256 public totalDebt;

    // Events
    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event TokensMinted(address indexed user, uint256 amount);
    event TokensRedeemed(address indexed user, uint256 amount);
    event LiquidationExecuted(
        address indexed liquidator,
        address indexed user,
        uint256 collateralReceived,
        uint256 debtRepaid,
        uint256 penalty
    );

    /**
     * @dev Constructor initializes the vault with token and oracle contracts
     * @param _equiAsset Address of the EquiAsset token contract
     * @param _oracle Address of the ChainlinkOracle contract
     */
    constructor(address _equiAsset, address _oracle) Ownable(msg.sender) {
        equiAsset = EquiAsset(_equiAsset);
        oracle = ChainlinkOracle(_oracle);
    }

    /**
     * @dev Deposit ETH as collateral
     */
    function depositCollateral() external payable nonReentrant {
        require(msg.value > 0, "Must deposit ETH");

        vaults[msg.sender].collateralBalance += msg.value;
        vaults[msg.sender].exists = true;
        totalCollateral += msg.value;

        emit CollateralDeposited(msg.sender, msg.value);
    }

    /**
     * @dev Withdraw ETH collateral (must maintain minimum collateral ratio)
     * @param amount Amount of ETH to withdraw
     */
    function withdrawCollateral(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be positive");
        require(
            vaults[msg.sender].collateralBalance >= amount,
            "Insufficient collateral"
        );

        uint256 newCollateralBalance = vaults[msg.sender].collateralBalance -
            amount;

        // Check if user has debt, ensure minimum collateral ratio is maintained
        if (vaults[msg.sender].debtAmount > 0) {
            require(
                getCollateralRatio(msg.sender, newCollateralBalance) >=
                    MIN_COLLATERAL_RATIO,
                "Would violate minimum collateral ratio"
            );
        }

        vaults[msg.sender].collateralBalance = newCollateralBalance;
        totalCollateral -= amount;

        // If no collateral and no debt, remove vault
        if (
            vaults[msg.sender].collateralBalance == 0 &&
            vaults[msg.sender].debtAmount == 0
        ) {
            vaults[msg.sender].exists = false;
        }

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");

        emit CollateralWithdrawn(msg.sender, amount);
    }

    /**
     * @dev Mint synthetic eNVDA tokens based on collateral value
     * @param amount Amount of eNVDA tokens to mint
     */
    function mintEquiNVDA(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be positive");
        require(
            vaults[msg.sender].collateralBalance > 0,
            "No collateral deposited"
        );

        // Calculate collateral value in USD
        (int256 ethUsdPrice, ) = oracle.getEthUsdPrice();
        uint256 collateralValueUsd = (vaults[msg.sender].collateralBalance *
            uint256(ethUsdPrice)) / 1e8;

        // Calculate new debt amount
        uint256 newDebtAmount = vaults[msg.sender].debtAmount + amount;

        // Calculate debt value in USD
        int256 nvdaUsdPrice = oracle.getNvdaUsdPrice();
        uint256 debtValueUsd = (newDebtAmount * uint256(nvdaUsdPrice)) / 1e8;

        // Ensure minimum collateral ratio is maintained
        require(
            (collateralValueUsd * PRECISION) / debtValueUsd >=
                MIN_COLLATERAL_RATIO,
            "Would violate minimum collateral ratio"
        );

        vaults[msg.sender].debtAmount = newDebtAmount;
        vaults[msg.sender].exists = true;
        totalDebt += amount;

        equiAsset.mint(msg.sender, amount);

        emit TokensMinted(msg.sender, amount);
    }

    /**
     * @dev Redeem synthetic tokens to withdraw collateral
     * @param amount Amount of eNVDA tokens to redeem
     */
    function redeemCollateral(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be positive");
        require(
            vaults[msg.sender].debtAmount >= amount,
            "Insufficient debt to redeem"
        );
        require(
            equiAsset.balanceOf(msg.sender) >= amount,
            "Insufficient token balance"
        );

        // Calculate collateral value in USD
        (int256 ethUsdPrice, ) = oracle.getEthUsdPrice();
        uint256 collateralValueUsd = (vaults[msg.sender].collateralBalance *
            uint256(ethUsdPrice)) / 1e8;

        // Calculate debt value in USD
        int256 nvdaUsdPrice = oracle.getNvdaUsdPrice();
        uint256 debtValueUsd = (amount * uint256(nvdaUsdPrice)) / 1e8;

        // Calculate ETH to withdraw based on debt value
        uint256 ethToWithdraw = (debtValueUsd * 1e8) / uint256(ethUsdPrice);

        require(
            ethToWithdraw <= vaults[msg.sender].collateralBalance,
            "Insufficient collateral"
        );

        vaults[msg.sender].debtAmount -= amount;
        vaults[msg.sender].collateralBalance -= ethToWithdraw;
        totalDebt -= amount;
        totalCollateral -= ethToWithdraw;

        // If no collateral and no debt, remove vault
        if (
            vaults[msg.sender].collateralBalance == 0 &&
            vaults[msg.sender].debtAmount == 0
        ) {
            vaults[msg.sender].exists = false;
        }

        equiAsset.burnFromVault(msg.sender, amount);

        (bool success, ) = msg.sender.call{value: ethToWithdraw}("");
        require(success, "ETH transfer failed");

        emit TokensRedeemed(msg.sender, amount);
    }

    /**
     * @dev Liquidate an under-collateralized vault
     * @param user Address of the user to liquidate
     */
    function liquidate(address user) external nonReentrant {
        require(user != msg.sender, "Cannot liquidate yourself");
        require(vaults[user].exists, "Vault does not exist");
        require(vaults[user].debtAmount > 0, "No debt to liquidate");

        uint256 collateralRatio = getCollateralRatio(user);
        require(
            collateralRatio < LIQUIDATION_THRESHOLD,
            "Vault not liquidatable"
        );

        // Calculate liquidation amounts
        uint256 debtToRepay = vaults[user].debtAmount;
        uint256 collateralToReceive = calculateLiquidationAmount(user);
        uint256 penalty = (collateralToReceive * LIQUIDATION_PENALTY) /
            PRECISION;
        uint256 collateralForLiquidator = collateralToReceive + penalty;

        require(
            collateralForLiquidator <= vaults[user].collateralBalance,
            "Insufficient collateral for liquidation"
        );

        // Update vault state
        vaults[user].debtAmount = 0;
        vaults[user].collateralBalance -= collateralForLiquidator;
        totalDebt -= debtToRepay;
        totalCollateral -= collateralForLiquidator;

        // If no collateral and no debt, remove vault
        if (
            vaults[user].collateralBalance == 0 && vaults[user].debtAmount == 0
        ) {
            vaults[user].exists = false;
        }

        // Transfer tokens from liquidator to vault (burn them)
        equiAsset.burnFromVault(msg.sender, debtToRepay);

        // Transfer collateral to liquidator
        (bool success, ) = msg.sender.call{value: collateralForLiquidator}("");
        require(success, "ETH transfer failed");

        emit LiquidationExecuted(
            msg.sender,
            user,
            collateralForLiquidator,
            debtToRepay,
            penalty
        );
    }

    /**
     * @dev Get collateral ratio for a user
     * @param user Address of the user
     * @return ratio Collateral ratio as percentage (e.g., 500 = 500%)
     */
    function getCollateralRatio(
        address user
    ) public view returns (uint256 ratio) {
        return getCollateralRatio(user, vaults[user].collateralBalance);
    }

    /**
     * @dev Get collateral ratio for a user with custom collateral amount
     * @param user Address of the user
     * @param collateralAmount Custom collateral amount to use in calculation
     * @return ratio Collateral ratio as percentage
     */
    function getCollateralRatio(
        address user,
        uint256 collateralAmount
    ) public view returns (uint256 ratio) {
        if (vaults[user].debtAmount == 0) {
            return type(uint256).max; // Infinite ratio if no debt
        }

        (int256 ethUsdPrice, ) = oracle.getEthUsdPrice();
        int256 nvdaUsdPrice = oracle.getNvdaUsdPrice();

        uint256 collateralValueUsd = (collateralAmount * uint256(ethUsdPrice)) /
            1e8;
        uint256 debtValueUsd = (vaults[user].debtAmount *
            uint256(nvdaUsdPrice)) / 1e8;

        return (collateralValueUsd * PRECISION) / debtValueUsd;
    }

    /**
     * @dev Calculate liquidation amount (collateral to receive for debt repayment)
     * @param user Address of the user
     * @return amount Amount of ETH collateral to receive
     */
    function calculateLiquidationAmount(
        address user
    ) public view returns (uint256 amount) {
        (int256 ethUsdPrice, ) = oracle.getEthUsdPrice();
        int256 nvdaUsdPrice = oracle.getNvdaUsdPrice();

        uint256 debtValueUsd = (vaults[user].debtAmount *
            uint256(nvdaUsdPrice)) / 1e8;
        return (debtValueUsd * 1e8) / uint256(ethUsdPrice);
    }

    /**
     * @dev Get vault data for a user
     * @param user Address of the user
     * @return collateralBalance ETH collateral balance
     * @return debtAmount eNVDA debt amount
     * @return collateralRatio Current collateral ratio
     * @return exists Whether vault exists
     */
    function getVaultData(
        address user
    )
        external
        view
        returns (
            uint256 collateralBalance,
            uint256 debtAmount,
            uint256 collateralRatio,
            bool exists
        )
    {
        VaultData memory vault = vaults[user];
        return (
            vault.collateralBalance,
            vault.debtAmount,
            getCollateralRatio(user),
            vault.exists
        );
    }

    /**
     * @dev Get latest prices from oracle
     * @return ethUsdPrice ETH/USD price
     * @return nvdaUsdPrice NVDA/USD price
     */
    function getLatestPrices()
        external
        view
        returns (int256 ethUsdPrice, int256 nvdaUsdPrice)
    {
        (ethUsdPrice, ) = oracle.getEthUsdPrice();
        nvdaUsdPrice = oracle.getNvdaUsdPrice();
    }

    /**
     * @dev Receive ETH
     */
    receive() external payable {
        // Allow contract to receive ETH
    }
}
