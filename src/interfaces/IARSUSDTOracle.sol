// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IARSUSDTOracle {
    error ARSUSDTOracle__StaleData();
    error ARSUSDTOracle__PriceError();
    error ARSUSDTOracle__NotAuthorized();

    /**
     * @notice Returns the latest ARS/USDT price if data is considered fresh.
     * @dev Reverts if the oracle data is stale according to maxAge or price is 0.
     * @param maxAge Maximum allowable age of data (in seconds).
     * @return answer The latest ARS/USDT price answer (scaled).
     */
    function latestValidData(uint256 maxAge) external view returns (uint256 answer);

    /**
     * @notice Returns the latest price and timestamp.
     * @return answer Latest ARS/USDT price
     * @return updateTimestamp Timestamp when last updated
     */
    function latestData() external view returns (uint256 answer, uint256 updateTimestamp);

    /**
     * @notice Check if data is stale.
     * @param maxAge Maximum age allowed since last update (seconds).
     * @return True if data is stale.
     */
    function isStale(uint256 maxAge) external view returns (bool);
}
