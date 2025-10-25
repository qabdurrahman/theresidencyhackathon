//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@chainlink/contracts/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ChainlinkOracle
 * @dev Oracle contract that provides price feeds for ETH/USD (real Chainlink) and NVDA/USD (mock)
 * @author EquiNVDA Protocol
 */
contract ChainlinkOracle is Ownable {
    // Chainlink ETH/USD price feed on Sepolia
    AggregatorV3Interface public immutable ethUsdPriceFeed;

    // Mock NVDA/USD price (8 decimals)
    int256 public mockNvdaUsdPrice;

    // Events
    event MockPriceUpdated(int256 oldPrice, int256 newPrice);

    /**
     * @dev Constructor sets up the ETH/USD Chainlink feed and initial NVDA price
     * @param _ethUsdPriceFeed Address of Chainlink ETH/USD price feed on Sepolia
     * @param _initialNvdaPrice Initial mock NVDA/USD price (8 decimals)
     */
    constructor(
        address _ethUsdPriceFeed,
        int256 _initialNvdaPrice
    ) Ownable(msg.sender) {
        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeed);
        mockNvdaUsdPrice = _initialNvdaPrice;
    }

    /**
     * @dev Get the latest ETH/USD price from Chainlink
     * @return price ETH/USD price with 8 decimals
     * @return timestamp Block timestamp when price was last updated
     */
    function getEthUsdPrice()
        public
        view
        returns (int256 price, uint256 timestamp)
    {
        (
            ,
            /* uint80 roundID */ int256 answer,
            ,
            /* uint256 startedAt */ uint256 updatedAt,

        ) = /* uint80 answeredInRound */
            ethUsdPriceFeed.latestRoundData();

        require(answer > 0, "Invalid ETH/USD price");
        require(updatedAt > 0, "Price feed not updated");

        return (answer, updatedAt);
    }

    /**
     * @dev Get the current mock NVDA/USD price
     * @return price NVDA/USD price with 8 decimals
     */
    function getNvdaUsdPrice() public view returns (int256 price) {
        return mockNvdaUsdPrice;
    }

    /**
     * @dev Update the mock NVDA/USD price (owner only)
     * @param _newPrice New NVDA/USD price with 8 decimals
     */
    function updateMockPrice(int256 _newPrice) external onlyOwner {
        require(_newPrice > 0, "Price must be positive");

        int256 oldPrice = mockNvdaUsdPrice;
        mockNvdaUsdPrice = _newPrice;

        emit MockPriceUpdated(oldPrice, _newPrice);
    }

    /**
     * @dev Simulate price fluctuation by adding/subtracting small random amounts
     * @param _maxChange Maximum percentage change (in basis points, e.g., 100 = 1%)
     */
    function simulatePriceFluctuation(uint256 _maxChange) external onlyOwner {
        require(_maxChange <= 1000, "Max change too high"); // Max 10%

        // Generate pseudo-random number based on block data
        uint256 random = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.prevrandao,
                    blockhash(block.number - 1)
                )
            )
        );

        // Calculate change amount (0 to _maxChange basis points)
        uint256 changeBps = random % (_maxChange + 1);

        // Determine if price goes up or down
        bool increase = random % 2 == 0;

        // Calculate new price
        int256 changeAmount = (mockNvdaUsdPrice * int256(changeBps)) / 10000;

        int256 newPrice;
        if (increase) {
            newPrice = mockNvdaUsdPrice + changeAmount;
        } else {
            newPrice = mockNvdaUsdPrice - changeAmount;
            require(newPrice > 0, "Price cannot be negative");
        }

        int256 oldPrice = mockNvdaUsdPrice;
        mockNvdaUsdPrice = newPrice;

        emit MockPriceUpdated(oldPrice, newPrice);
    }
}
