//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ChainlinkOracle
 * @dev Oracle contract that integrates with Chainlink NVDA/USD price feed
 * Falls back to mock price mode if Chainlink feed is unavailable
 * @author EquiNVDA Protocol
 */
contract ChainlinkOracle is Ownable {
    /// @notice Chainlink NVDA/USD price feed aggregator
    AggregatorV3Interface public immutable priceFeed;

    /// @notice Fallback mock price for testing when Chainlink feed is unavailable
    int256 public mockPrice;

    /// @notice Whether to use mock price instead of Chainlink feed
    bool public useMockPrice;

    /// @notice Price decimals (Chainlink feeds typically use 8 decimals)
    uint8 public constant PRICE_DECIMALS = 8;

    /// @notice Maximum price staleness (24 hours in seconds)
    uint256 public constant MAX_STALENESS = 24 hours;

    /// @notice Event emitted when mock price is updated
    event MockPriceUpdated(int256 newPrice, address updatedBy);

    /// @notice Event emitted when oracle mode is switched
    event OracleModeSwitched(bool useMock, address switchedBy);

    /**
     * @dev Constructor sets up the Chainlink price feed
     * @param _priceFeed Address of the Chainlink NVDA/USD aggregator
     * @param _initialMockPrice Initial mock price for fallback mode
     */
    constructor(
        address _priceFeed,
        int256 _initialMockPrice
    ) Ownable(msg.sender) {
        require(
            _priceFeed != address(0),
            "ChainlinkOracle: Invalid price feed address"
        );
        priceFeed = AggregatorV3Interface(_priceFeed);
        mockPrice = _initialMockPrice;
        useMockPrice = false;
    }

    /**
     * @dev Gets the latest NVDA/USD price from Chainlink or mock
     * @return price Current NVDA price in USD (with 8 decimals)
     * @return timestamp When the price was last updated
     */
    function getLatestPrice()
        public
        view
        returns (int256 price, uint256 timestamp)
    {
        if (useMockPrice) {
            return (mockPrice, block.timestamp);
        }

        try priceFeed.latestRoundData() returns (
            uint80,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80
        ) {
            // Check if price is stale (older than MAX_STALENESS)
            require(
                block.timestamp - updatedAt <= MAX_STALENESS,
                "ChainlinkOracle: Price is stale"
            );

            // Check if price is valid (greater than 0)
            require(
                answer > 0,
                "ChainlinkOracle: Invalid price from Chainlink"
            );

            return (answer, updatedAt);
        } catch {
            // If Chainlink fails, revert with helpful message
            revert("ChainlinkOracle: Failed to fetch price from Chainlink");
        }
    }

    /**
     * @dev Gets the latest NVDA/USD price, falling back to mock if Chainlink fails
     * @return price Current NVDA price in USD (with 8 decimals)
     * @return timestamp When the price was last updated
     * @return isFromMock Whether the price came from mock or Chainlink
     */
    function getLatestPriceWithFallback()
        public
        view
        returns (int256 price, uint256 timestamp, bool isFromMock)
    {
        if (useMockPrice) {
            return (mockPrice, block.timestamp, true);
        }

        try priceFeed.latestRoundData() returns (
            uint80,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80
        ) {
            // Check if price is stale
            if (block.timestamp - updatedAt > MAX_STALENESS) {
                return (mockPrice, block.timestamp, true);
            }

            // Check if price is valid
            if (answer <= 0) {
                return (mockPrice, block.timestamp, true);
            }

            return (answer, updatedAt, false);
        } catch {
            // Fallback to mock price if Chainlink fails
            return (mockPrice, block.timestamp, true);
        }
    }

    /**
     * @dev Updates the mock price (only owner)
     * @param _newPrice New mock price in USD with 8 decimals
     */
    function updateMockPrice(int256 _newPrice) external onlyOwner {
        require(_newPrice > 0, "ChainlinkOracle: Mock price must be positive");
        mockPrice = _newPrice;
        emit MockPriceUpdated(_newPrice, msg.sender);
    }

    /**
     * @dev Switches between Chainlink and mock price mode (only owner)
     * @param _useMock Whether to use mock price instead of Chainlink
     */
    function setUseMockPrice(bool _useMock) external onlyOwner {
        useMockPrice = _useMock;
        emit OracleModeSwitched(_useMock, msg.sender);
    }

    /**
     * @dev Gets the price feed address
     * @return Address of the Chainlink price feed
     */
    function getPriceFeedAddress() external view returns (address) {
        return address(priceFeed);
    }

    /**
     * @dev Gets the price decimals
     * @return Number of decimals for the price
     */
    function getPriceDecimals() external pure returns (uint8) {
        return PRICE_DECIMALS;
    }

    /**
     * @dev Checks if the current price is stale
     * @return True if price is stale, false otherwise
     */
    function isPriceStale() external view returns (bool) {
        if (useMockPrice) {
            return false; // Mock price is never stale
        }

        try priceFeed.latestRoundData() returns (
            uint80,
            int256,
            uint256,
            uint256 updatedAt,
            uint80
        ) {
            return block.timestamp - updatedAt > MAX_STALENESS;
        } catch {
            return true; // If we can't fetch, consider it stale
        }
    }
}
