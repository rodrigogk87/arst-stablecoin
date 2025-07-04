// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ACLManager} from "./ACLManager.sol";

contract ARSUSDTOracle {
    error ARSUSDTOracle__StaleData();
    error ARSUSDTOracle__PriceError();
    error ARSUSDTOracle__NotAuthorized();

    uint256 public latestAnswer; // Último precio (scaled, e.g., 1e8)
    uint256 public lastUpdateTimestamp; // Timestamp de la última actualización

    event PriceUpdated(uint256 newPrice, uint256 timestamp);

    ACLManager private immutable aclManager;

    constructor(address _aclManager) {
        aclManager = ACLManager(_aclManager);
        latestAnswer = 0;
        lastUpdateTimestamp = block.timestamp;
    }

    function updatePrice(uint256 newPrice) external {
        // Check if sender has PRICE_UPDATER_ROLE
        if (!aclManager.hasRole(aclManager.PRICE_UPDATER_ROLE(), msg.sender)) {
            revert ARSUSDTOracle__NotAuthorized();
        }

        latestAnswer = newPrice;
        lastUpdateTimestamp = block.timestamp;
        emit PriceUpdated(newPrice, lastUpdateTimestamp);
    }

    function latestValidData(uint256 maxAge) external view returns (uint256 answer) {
        if (isStale(maxAge)) revert ARSUSDTOracle__StaleData();
        if (latestAnswer == 0) revert ARSUSDTOracle__PriceError();
        return latestAnswer;
    }

    function latestData() external view returns (uint256 answer, uint256 updateTimestamp) {
        return (latestAnswer, lastUpdateTimestamp);
    }

    function isStale(uint256 maxAge) public view returns (bool) {
        return block.timestamp - lastUpdateTimestamp > maxAge;
    }
}
