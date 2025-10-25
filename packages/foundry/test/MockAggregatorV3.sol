//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@chainlink/contracts/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title MockAggregatorV3
 * @dev Mock implementation of Chainlink AggregatorV3Interface for testing
 * @author EquiNVDA Protocol
 */
contract MockAggregatorV3 is AggregatorV3Interface {
    int256 public price;
    uint256 public timestamp;
    uint80 public roundId;

    constructor(int256 _initialPrice) {
        price = _initialPrice;
        timestamp = block.timestamp;
        roundId = 1;
    }

    function setPrice(int256 _newPrice) external {
        price = _newPrice;
        timestamp = block.timestamp;
        roundId++;
    }

    function latestRoundData()
        external
        view
        override
        returns (
            uint80,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (roundId, price, timestamp, timestamp, roundId);
    }

    function getRoundData(
        uint80 _roundId
    )
        external
        view
        override
        returns (
            uint80,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (_roundId, price, timestamp, timestamp, _roundId);
    }

    function description() external pure override returns (string memory) {
        return "Mock ETH/USD Price Feed";
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function decimals() external pure override returns (uint8) {
        return 8;
    }
}
