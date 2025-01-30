// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title OracleLib
 * @author Mauro
 * @notice This library is used to check chainlink oracle for stale data
 * if price is stale the function will revert and render dscengine unusable
 * we want the dsce to freeze if price has became stale
 * if chainlink explodes you'd have lots of money locked in the protocol
 */
library OracleLib {
    error OracleLib__StalePrice();
    uint256 private constant TIMEOUT = 3 hours; // 3 * 60 * 60 * 10800 seconds

    function staleCheckLatestRoundData(
        AggregatorV3Interface priceFeed
    ) public view returns (uint80, int256, uint256, uint256, uint80) {
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();

        uint256 secondSince = block.timestamp - updatedAt;
        if (secondSince > TIMEOUT) revert OracleLib__StalePrice();
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
