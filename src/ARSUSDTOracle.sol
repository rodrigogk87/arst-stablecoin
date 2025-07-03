// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ARSUSDTOracle is Ownable {
    error ARSUSDTOracle__StaleData();
    error ARSUSDTOracle__PriceError();
    error ARSUSDTOracle__NotAuthorized();

    uint256 public latestAnswer; // Último precio (scaled, e.g., 1e8)
    uint256 public lastUpdateTimestamp; // Timestamp de la última actualización

    event PriceUpdated(uint256 newPrice, uint256 timestamp);

    constructor() Ownable(msg.sender) {
        latestAnswer = 0;
        lastUpdateTimestamp = block.timestamp;
    }

    function updatePrice(uint256 newPrice) external onlyOwner {
        latestAnswer = newPrice;
        lastUpdateTimestamp = block.timestamp;
        emit PriceUpdated(newPrice, lastUpdateTimestamp);
    }

    function latestValidData(
        uint256 maxAge
    ) external view returns (uint256 answer) {
        if (isStale(maxAge)) revert ARSUSDTOracle__StaleData();
        if (latestAnswer == 0) revert ARSUSDTOracle__PriceError();
        return latestAnswer;
    }

    function latestData()
        external
        view
        returns (uint256 answer, uint256 updateTimestamp)
    {
        return (latestAnswer, lastUpdateTimestamp);
    }

    function isStale(uint256 maxAge) public view returns (bool) {
        return block.timestamp - lastUpdateTimestamp > maxAge;
    }
}
