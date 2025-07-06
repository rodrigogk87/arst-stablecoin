// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ARSXStableCoin} from "./ARSXStableCoin.sol";
import {ACLManager} from "./ACLManager.sol";
import {IARSUSDTOracle} from "./interfaces/IARSUSDTOracle.sol";

/**
 * @title Peg Stability Module (PSM)
 * @author Rodrigo Garcia Kosinski
 * @notice Allows direct swaps between ARSX and a collateral token (e.g., USDC), using the ARS/USDT oracle to calculate amounts.
 */
contract PSM {
    error PSM__AmountMustBeMoreThanZero();
    error PSM__TransferFailed();
    error PSM__NotEnoughCollateral();
    error PSM__RedeemThresholdTooHigh();

    IERC20 public immutable collateralToken;
    ARSXStableCoin public immutable arsx;
    ACLManager public immutable aclManager;
    IARSUSDTOracle public immutable arsxOracle;

    uint256 public feeBps; // e.g., 30 = 0.3%
    uint256 public redeemThreshold; // e.g., 0.95 * 1e18 = 95% of balance
    uint256 public maxOracleAge = 3600; // e.g., 1 hour

    /**
     * @notice PSM contract constructor
     * @param _collateralToken Address of the collateral token (e.g., USDC)
     * @param _arsx Address of the ARSX token
     * @param _aclManager Address of the ACLManager
     * @param _arsxOracle Address of the ARS/USDT oracle
     * @param _feeBps Fee in basis points (bps). 100 bps = 1%
     * @param _redeemThreshold Maximum redemption threshold, e.g., 0.95 * 1e18
     */
    constructor(
        address _collateralToken,
        address _arsx,
        address _aclManager,
        address _arsxOracle,
        uint256 _feeBps,
        uint256 _redeemThreshold
    ) {
        if (_redeemThreshold > 1e18) revert PSM__RedeemThresholdTooHigh();
        collateralToken = IERC20(_collateralToken);
        arsx = ARSXStableCoin(_arsx);
        aclManager = ACLManager(_aclManager);
        arsxOracle = IARSUSDTOracle(_arsxOracle);
        feeBps = _feeBps;
        redeemThreshold = _redeemThreshold;
    }

    /**
     * @notice Updates the fee in basis points
     * @param newFeeBps New fee in bps (1% = 100)
     */
    function setFee(uint256 newFeeBps) external {
        aclManager.checkConfigAdmin(msg.sender);
        feeBps = newFeeBps;
    }

    /**
     * @notice Updates the maximum redemption threshold
     * @param newThreshold New threshold, must be <= 1e18 (100%)
     */
    function setRedeemThreshold(uint256 newThreshold) external {
        aclManager.checkConfigAdmin(msg.sender);
        if (newThreshold > 1e18) revert PSM__RedeemThresholdTooHigh();
        redeemThreshold = newThreshold;
    }

    /**
     * @notice Updates the maximum allowed oracle data age
     * @param newMaxAge New maximum age in seconds
     */
    function setMaxOracleAge(uint256 newMaxAge) external {
        aclManager.checkConfigAdmin(msg.sender);
        maxOracleAge = newMaxAge;
    }

    /**
     * @notice Swaps collateral (e.g., USDC) for ARSX, minting ARSX based on the oracle price
     * @param collateralAmount Amount of collateral token provided
     */
    function swapCollateralForARSX(uint256 collateralAmount) external {
        if (collateralAmount == 0) revert PSM__AmountMustBeMoreThanZero();

        uint256 priceARSPerUSDT = arsxOracle.latestValidData(maxOracleAge);
        uint256 arsxAmount = (collateralAmount * priceARSPerUSDT) / 1e8;

        uint256 fee = (arsxAmount * feeBps) / 10_000;
        uint256 netARSX = arsxAmount - fee;

        bool success = collateralToken.transferFrom(
            msg.sender,
            address(this),
            collateralAmount
        );
        if (!success) revert PSM__TransferFailed();

        bool minted = arsx.mint(msg.sender, netARSX);
        if (!minted) revert PSM__TransferFailed();
    }

    /**
     * @notice Swaps ARSX for collateral (e.g., USDC), burning ARSX and returning collateral based on the oracle price
     * @param arsxAmount Amount of ARSX provided
     */
    function swapARSXForCollateral(uint256 arsxAmount) external {
        if (arsxAmount == 0) revert PSM__AmountMustBeMoreThanZero();

        uint256 priceARSPerUSDT = arsxOracle.latestValidData(maxOracleAge);
        uint256 collateralAmount = (arsxAmount * 1e8) / priceARSPerUSDT;

        uint256 fee = (collateralAmount * feeBps) / 10_000;
        uint256 netCollateral = collateralAmount - fee;

        uint256 collateralBalance = collateralToken.balanceOf(address(this));
        uint256 maxRedeemable = (collateralBalance * redeemThreshold) / 1e18;

        if (netCollateral > maxRedeemable) revert PSM__NotEnoughCollateral();

        bool success = arsx.transferFrom(msg.sender, address(this), arsxAmount);
        if (!success) revert PSM__TransferFailed();

        arsx.burn(arsxAmount);

        success = collateralToken.transfer(msg.sender, netCollateral);
        if (!success) revert PSM__TransferFailed();
    }

    /**
     * @notice Allows emergency collateral withdrawal by an emergency admin
     * @param to Address receiving the collateral
     * @param amount Amount to withdraw
     */
    function withdrawCollateral(address to, uint256 amount) external {
        aclManager.checkEmergencyAdmin(msg.sender);
        collateralToken.transfer(to, amount);
    }
}
