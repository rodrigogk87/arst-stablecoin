// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IARSUSDTOracle} from "../src/interfaces/IARSUSDTOracle.sol";

contract ARSMockOracle is IARSUSDTOracle {
    uint256 private answer; // latest price (e.g., 1200 * 1e8)
    uint256 private requestTs;

    constructor() {
        // Default price: 1200 ARS per USDT, scaled to 1e8
        answer = 83333; // → 0.000833 * 1e8 ≈ 83_333
    }

    function setAnswer(uint256 newAnswer) external {
        answer = newAnswer;
        requestTs = block.timestamp;
    }

    function latestAnswer() external view returns (uint256) {
        return answer;
    }

    function lastRequestTimestamp() external view returns (uint256) {
        return requestTs;
    }

    function isStale(uint256 maxAge) external view override returns (bool) {
        if (block.timestamp - requestTs > maxAge) {
            return true;
        }
        return false;
    }

    function latestData() external view override returns (uint256, uint256) {
        return (answer, requestTs);
    }

    function latestValidData(
        uint256
    )
        external
        view
        returns (
            /*maxAge*/
            uint256
        )
    {
        return answer;
    }
}
