// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IARSUSDTOracle} from "../src/interfaces/IARSUSDTOracle.sol";

contract ARSMockOracle is IARSUSDTOracle {
    uint256 private answer; // latest price (e.g., 1200 * 1e8)
    bytes32 private requestId;
    uint256 private requestTs;
    uint256 private fulfillTs;

    constructor() {
        // Default price: 1200 ARS per USDT, scaled to 1e8
        answer = 83333; // → 0.000833 * 1e8 ≈ 83_333
        requestId = bytes32(uint256(1)); // dummy request id
    }

    function setAnswer(uint256 newAnswer) external {
        answer = newAnswer;
        requestId = bytes32(
            uint256(keccak256(abi.encode(newAnswer, block.timestamp)))
        );
    }

    function latestAnswer() external view override returns (uint256) {
        return answer;
    }

    function lastRequestId() external view override returns (bytes32) {
        return requestId;
    }

    function lastRequestTimestamp() external view override returns (uint256) {
        return requestTs;
    }

    function lastFulfillTimestamp() external view override returns (uint256) {
        return fulfillTs;
    }

    function isStale(
        uint256 maxAge,
        uint256 maxDelay
    ) external view override returns (bool) {
        if (block.timestamp - fulfillTs > maxAge) {
            return true;
        }
        if (fulfillTs - requestTs > maxDelay) {
            return true;
        }
        return false;
    }

    function latestData()
        external
        view
        override
        returns (uint256, uint256, uint256)
    {
        return (answer, requestTs, fulfillTs);
    }
}
