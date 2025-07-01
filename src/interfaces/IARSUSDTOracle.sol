// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IARSUSDTOracle {
    /**
     * @notice Returns the latest ARS/USDT answer (scaled, e.g., 1e8)
     */
    function latestAnswer() external view returns (uint256);

    /**
     * @notice Returns the ID of the last request sent
     */
    function lastRequestId() external view returns (bytes32);

    /**
     * @notice Timestamp when the last request was sent
     */
    function lastRequestTimestamp() external view returns (uint256);

    /**
     * @notice Timestamp when the last request was fulfilled
     */
    function lastFulfillTimestamp() external view returns (uint256);

    /**
     * @notice Check if the latestAnswer data is stale
     * @param maxAge Maximum age allowed since last fulfillment (seconds)
     * @param maxDelay Maximum delay allowed between request and fulfillment (seconds)
     * @return isDataStale True if data is stale or delayed
     */
    function isStale(
        uint256 maxAge,
        uint256 maxDelay
    ) external view returns (bool isDataStale);

    /**
     * @notice Returns the latest price data along with timestamps
     * @return answer Latest ARS/USDT answer
     * @return requestTimestamp Timestamp when the request was sent
     * @return fulfillTimestamp Timestamp when the request was fulfilled
     */
    function latestData()
        external
        view
        returns (
            uint256 answer,
            uint256 requestTimestamp,
            uint256 fulfillTimestamp
        );
}
