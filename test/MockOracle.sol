// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract MockOracle is AggregatorV3Interface {
    int public price; // ✅ Variable de estado para el precio

    constructor() {
        price = 2000e8; // Valor inicial por defecto: $2000
    }

    function decimals() external pure override returns (uint8) {
        return 8;
    }

    function description() external pure override returns (string memory) {
        return "Mock";
    }

    function version() external pure override returns (uint) {
        return 1;
    }

    function getRoundData(
        uint80
    ) external view override returns (uint80, int, uint, uint, uint80) {
        return (0, price, block.timestamp - 60, block.timestamp - 60, 0);
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80, int, uint, uint, uint80)
    {
        return (0, price, block.timestamp - 60, block.timestamp - 60, 0);
    }

    function setPrice(int newPrice) external {
        price = newPrice;
    }
}
