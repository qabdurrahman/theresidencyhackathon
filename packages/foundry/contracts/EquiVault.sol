//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./EquiAsset.sol";
import "./ChainlinkOracle.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "forge-std/console.sol";

/**
 * @title EquiVault
 * @dev Main vault contract managing ETH collateral, minting, redemption, and liquidation
 * Implements a synthetic asset protocol for NVDA tokens backed by ETH collateral
 * @author EquiNVDA Protocol
 */
contract EquiVault is Ownable, ReentrancyGuard {
    /// @notice EquiNVDA token contract
    EquiAsset public immutable equiAsset;

    /// @notice Chainlink oracle for NVDA/USD price
    ChainlinkOracle public immutable oracle;

    /// @notice Minimum collateralization ratio (150% = 15000 basis points)
    uint256 public constant MIN_COLLATERAL_RATIO = 15000; // 150%

    /// @notice Liquidation threshold (130% = 13000 basis points)
    uint256 public constant LIQUIDATION_THRESHOLD = 13000; // 130%

    /// @notice Liquidation penalty (10% = 1000 basis points)
    uint256 public constant LIQUIDATION_PENALTY = 1000; // 10%

    /// @notice Basis points denominator (100% = 10000)
    uint256 public constant BASIS_POINTS = 10000;

    /// @notice ETH price feed for collateral valuation (ETH/USD)
    address public ethPriceFeed;

    /// @notice User collateral balances (in wei)
    mapping(address => uint256) public collateralBalance;

    /// @notice User debt amounts (in EquiNVDA tokens, 18 decimals)
    mapping(address => uint256) public debtAmount;

    /// @notice Total collateral in the system (in wei)
    uint256 public totalCollateral;

    /// @notice Total debt in the system (in EquiNVDA tokens)
    uint256 public totalDebt;

    /// @notice Protocol fee (in basis points, default 0.5% = 50)
    uint256 public protocolFee = 50;

    /// @notice Fee recipient address
    address public feeRecipient;

    /// @notice Events
    event CollateralDeposited(address indexed user, uint256 amount);
    event EquiNVDAMinted(
        address indexed user,
        uint256 amount,
        uint256 collateralRatio
    );
    event CollateralRedeemed(address indexed user, uint256 amount);
    event DebtRepaid(address indexed user, uint256 amount);
    event LiquidationExecuted(
        address indexed liquidator,
        address indexed user,
        uint256 collateralLiquidated,
        uint256 debtLiquidated,
        uint256 penalty
    );
    event ProtocolFeeUpdated(uint256 newFee);
    event FeeRecipientUpdated(address newRecipient);

    /**
     * @dev Constructor sets up the vault with required contracts
     * @param _equiAsset Address of the EquiNVDA token contract
     * @param _oracle Address of the Chainlink oracle contract
     * @param _ethPriceFeed Address of ETH/USD price feed
     * @param _feeRecipient Address to receive protocol fees
     */
    constructor(
        address _equiAsset,
        address _oracle,
        address _ethPriceFeed,
        address _feeRecipient
    ) Ownable(msg.sender) {
        require(
            _equiAsset != address(0),
            "EquiVault: Invalid EquiAsset address"
        );
        require(_oracle != address(0), "EquiVault: Invalid oracle address");
        require(
            _ethPriceFeed != address(0),
            "EquiVault: Invalid ETH price feed"
        );
        require(
            _feeRecipient != address(0),
            "EquiVault: Invalid fee recipient"
        );

        equiAsset = EquiAsset(_equiAsset);
        oracle = ChainlinkOracle(_oracle);
        ethPriceFeed = _ethPriceFeed;
        feeRecipient = _feeRecipient;
    }

    /**
     * @dev Deposits ETH as collateral
     */
    function depositCollateral() external payable nonReentrant {
        require(msg.value > 0, "EquiVault: Must deposit some ETH");

        collateralBalance[msg.sender] += msg.value;
        totalCollateral += msg.value;

        emit CollateralDeposited(msg.sender, msg.value);
    }

    /**
     * @dev Mints EquiNVDA tokens against ETH collateral
     * @param amount Amount of EquiNVDA tokens to mint (18 decimals)
     */
    function mintEquiNVDA(uint256 amount) external nonReentrant {
        require(amount > 0, "EquiVault: Amount must be greater than 0");

        // Get current prices
        (int256 nvdaPrice, , ) = oracle.getLatestPriceWithFallback();
        (int256 ethPrice, ) = getEthPrice();

        require(nvdaPrice > 0 && ethPrice > 0, "EquiVault: Invalid prices");

        // Calculate required collateral value in USD
        uint256 requiredCollateralValue = (amount * uint256(nvdaPrice)) /
            10 ** 18;
        uint256 requiredCollateralEth = (requiredCollateralValue * 10 ** 18) /
            uint256(ethPrice);

        // Apply minimum collateral ratio
        uint256 requiredCollateral = (requiredCollateralEth *
            MIN_COLLATERAL_RATIO) / BASIS_POINTS;

        require(
            collateralBalance[msg.sender] >= requiredCollateral,
            "EquiVault: Insufficient collateral"
        );

        // Update balances
        debtAmount[msg.sender] += amount;
        totalDebt += amount;

        // Mint tokens
        equiAsset.mint(msg.sender, amount);

        // Calculate and emit collateral ratio
        uint256 collateralRatio = getCollateralRatio(msg.sender);

        emit EquiNVDAMinted(msg.sender, amount, collateralRatio);
    }

    /**
     * @dev Redeems ETH collateral by burning EquiNVDA tokens
     * @param collateralAmount Amount of ETH collateral to redeem (in wei)
     */
    function redeemCollateral(uint256 collateralAmount) external nonReentrant {
        require(
            collateralAmount > 0,
            "EquiVault: Amount must be greater than 0"
        );
        require(
            collateralBalance[msg.sender] >= collateralAmount,
            "EquiVault: Insufficient collateral"
        );

        // Get current prices
        (int256 nvdaPrice, , ) = oracle.getLatestPriceWithFallback();
        (int256 ethPrice, ) = getEthPrice();

        require(nvdaPrice > 0 && ethPrice > 0, "EquiVault: Invalid prices");

        // Calculate collateral value in USD
        uint256 collateralValueUsd = (collateralAmount * uint256(ethPrice)) /
            10 ** 18;

        // Calculate maximum debt that can be maintained with remaining collateral
        uint256 remainingCollateral = collateralBalance[msg.sender] -
            collateralAmount;
        uint256 maxDebtValue = (remainingCollateral *
            uint256(ethPrice) *
            BASIS_POINTS) / (10 ** 18 * MIN_COLLATERAL_RATIO);
        uint256 maxDebtTokens = (maxDebtValue * 10 ** 18) / uint256(nvdaPrice);

        require(
            debtAmount[msg.sender] <= maxDebtTokens,
            "EquiVault: Would violate collateral ratio"
        );

        // Update balances
        collateralBalance[msg.sender] -= collateralAmount;
        totalCollateral -= collateralAmount;

        // Transfer ETH to user
        (bool success, ) = msg.sender.call{value: collateralAmount}("");
        require(success, "EquiVault: ETH transfer failed");

        emit CollateralRedeemed(msg.sender, collateralAmount);
    }

    /**
     * @dev Repays debt by burning EquiNVDA tokens
     * @param amount Amount of EquiNVDA tokens to burn (18 decimals)
     */
    function repayDebt(uint256 amount) external nonReentrant {
        require(amount > 0, "EquiVault: Amount must be greater than 0");
        require(
            debtAmount[msg.sender] >= amount,
            "EquiVault: Insufficient debt"
        );
        require(
            equiAsset.balanceOf(msg.sender) >= amount,
            "EquiVault: Insufficient token balance"
        );

        // Update balances
        debtAmount[msg.sender] -= amount;
        totalDebt -= amount;

        // Burn tokens
        equiAsset.burn(msg.sender, amount);

        emit DebtRepaid(msg.sender, amount);
    }

    /**
     * @dev Liquidates an under-collateralized position
     * @param user Address of the user to liquidate
     * @param maxDebtToLiquidate Maximum amount of debt to liquidate
     */
    function liquidate(
        address user,
        uint256 maxDebtToLiquidate
    ) external nonReentrant {
        require(user != address(0), "EquiVault: Invalid user address");
        require(
            maxDebtToLiquidate > 0,
            "EquiVault: Amount must be greater than 0"
        );

        uint256 collateralRatio = getCollateralRatio(user);
        require(
            collateralRatio < LIQUIDATION_THRESHOLD,
            "EquiVault: Position not liquidatable"
        );

        // Get current prices
        (int256 nvdaPrice, , ) = oracle.getLatestPriceWithFallback();
        (int256 ethPrice, ) = getEthPrice();

        require(nvdaPrice > 0 && ethPrice > 0, "EquiVault: Invalid prices");

        // Calculate liquidation amounts
        uint256 debtToLiquidate = maxDebtToLiquidate;
        if (debtToLiquidate > debtAmount[user]) {
            debtToLiquidate = debtAmount[user];
        }

        // Calculate collateral to liquidate (including penalty)
        uint256 collateralValueUsd = (debtToLiquidate * uint256(nvdaPrice)) /
            10 ** 18;
        uint256 collateralValueWithPenalty = (collateralValueUsd *
            (BASIS_POINTS + LIQUIDATION_PENALTY)) / BASIS_POINTS;
        uint256 collateralToLiquidate = (collateralValueWithPenalty *
            10 ** 18) / uint256(ethPrice);

        // If we can't liquidate all the requested debt due to insufficient collateral,
        // liquidate all available collateral and adjust debt accordingly
        if (collateralToLiquidate > collateralBalance[user]) {
            collateralToLiquidate = collateralBalance[user];
            // Calculate how much debt we can liquidate with available collateral
            uint256 maxCollateralValueUsd = (collateralBalance[user] *
                uint256(ethPrice)) / 10 ** 18;
            debtToLiquidate =
                (maxCollateralValueUsd * 10 ** 18) /
                (uint256(nvdaPrice) * (BASIS_POINTS + LIQUIDATION_PENALTY));
        }

        require(debtToLiquidate > 0, "EquiVault: Nothing to liquidate");

        // Update balances
        debtAmount[user] -= debtToLiquidate;
        totalDebt -= debtToLiquidate;
        collateralBalance[user] -= collateralToLiquidate;
        totalCollateral -= collateralToLiquidate;

        // Transfer EquiNVDA tokens from liquidator and burn them
        equiAsset.transferFrom(msg.sender, address(this), debtToLiquidate);
        equiAsset.burn(address(this), debtToLiquidate);

        // Transfer collateral to liquidator
        (bool success, ) = msg.sender.call{value: collateralToLiquidate}("");
        require(success, "EquiVault: ETH transfer failed");

        emit LiquidationExecuted(
            msg.sender,
            user,
            collateralToLiquidate,
            debtToLiquidate,
            LIQUIDATION_PENALTY
        );
    }

    /**
     * @dev Gets the collateral ratio for a user
     * @param user Address of the user
     * @return Collateral ratio in basis points (15000 = 150%)
     */
    function getCollateralRatio(address user) public view returns (uint256) {
        if (debtAmount[user] == 0) {
            return type(uint256).max; // No debt = infinite ratio
        }

        (int256 nvdaPrice, , ) = oracle.getLatestPriceWithFallback();
        (int256 ethPrice, ) = getEthPrice();

        if (nvdaPrice <= 0 || ethPrice <= 0) {
            return 0; // Invalid prices
        }

        uint256 collateralValueUsd = (collateralBalance[user] *
            uint256(ethPrice)) / 10 ** 18;
        uint256 debtValueUsd = (debtAmount[user] * uint256(nvdaPrice)) /
            10 ** 18;

        return (collateralValueUsd * BASIS_POINTS) / debtValueUsd;
    }

    /**
     * @dev Gets the latest ETH/USD price from Chainlink
     * @return price ETH price in USD (8 decimals)
     * @return timestamp When the price was last updated
     */
    function getEthPrice()
        public
        view
        returns (int256 price, uint256 timestamp)
    {
        AggregatorV3Interface ethFeed = AggregatorV3Interface(ethPriceFeed);

        try ethFeed.latestRoundData() returns (
            uint80,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80
        ) {
            require(answer > 0, "EquiVault: Invalid ETH price");
            return (answer, updatedAt);
        } catch {
            revert("EquiVault: Failed to fetch ETH price");
        }
    }

    /**
     * @dev Gets the latest NVDA/USD price from oracle
     * @return price NVDA price in USD (8 decimals)
     * @return timestamp When the price was last updated
     */
    function getLatestPrice()
        external
        view
        returns (int256 price, uint256 timestamp)
    {
        (price, timestamp, ) = oracle.getLatestPriceWithFallback();
    }

    /**
     * @dev Updates the protocol fee (only owner)
     * @param _newFee New protocol fee in basis points
     */
    function updateProtocolFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 1000, "EquiVault: Fee cannot exceed 10%");
        protocolFee = _newFee;
        emit ProtocolFeeUpdated(_newFee);
    }

    /**
     * @dev Updates the fee recipient (only owner)
     * @param _newRecipient New fee recipient address
     */
    function updateFeeRecipient(address _newRecipient) external onlyOwner {
        require(
            _newRecipient != address(0),
            "EquiVault: Invalid recipient address"
        );
        feeRecipient = _newRecipient;
        emit FeeRecipientUpdated(_newRecipient);
    }

    /**
     * @dev Updates the ETH price feed address (only owner)
     * @param _newFeed New ETH price feed address
     */
    function updateEthPriceFeed(address _newFeed) external onlyOwner {
        require(
            _newFeed != address(0),
            "EquiVault: Invalid price feed address"
        );
        ethPriceFeed = _newFeed;
    }

    /**
     * @dev Gets user position information
     * @param user Address of the user
     * @return collateral User's collateral balance (in wei)
     * @return debt User's debt amount (in EquiNVDA tokens)
     * @return ratio User's collateral ratio (in basis points)
     */
    function getUserPosition(
        address user
    ) external view returns (uint256 collateral, uint256 debt, uint256 ratio) {
        collateral = collateralBalance[user];
        debt = debtAmount[user];
        ratio = getCollateralRatio(user);
    }

    /**
     * @dev Gets system-wide information
     * @return totalCollateralAmount Total collateral in the system (in wei)
     * @return totalDebtAmount Total debt in the system (in EquiNVDA tokens)
     * @return nvdaPrice Current NVDA price (8 decimals)
     * @return ethPrice Current ETH price (8 decimals)
     */
    function getSystemInfo()
        external
        view
        returns (
            uint256 totalCollateralAmount,
            uint256 totalDebtAmount,
            int256 nvdaPrice,
            int256 ethPrice
        )
    {
        totalCollateralAmount = totalCollateral;
        totalDebtAmount = totalDebt;
        (nvdaPrice, , ) = oracle.getLatestPriceWithFallback();
        (ethPrice, ) = getEthPrice();
    }

    /**
     * @dev Allows the contract to receive ETH
     */
    receive() external payable {
        // ETH can be sent directly to the contract
    }
}
