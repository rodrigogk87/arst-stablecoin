// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ARSXStableCoin} from "./ARSXStableCoin.sol";
import {ACLManager} from "./ACLManager.sol";

/**
 * @title Peg Stability Module (PSM)
 * @author Tu equipo
 * @notice Permite swaps directos entre ARSX y un colateral (ej: USDC), manteniendo el peg y gestionando liquidez.
 */
contract PSM {
    error PSM__AmountMustBeMoreThanZero();
    error PSM__TransferFailed();
    error PSM__NotEnoughCollateral();
    error PSM__RedeemThresholdTooHigh();

    IERC20 public immutable collateralToken;
    ARSXStableCoin public immutable arsx;
    ACLManager public immutable aclManager;

    uint256 public feeBps; // ej: 30 = 0.3%
    uint256 public redeemThreshold; // ej: 0.95 * 1e18 = 95% del balance

    /**
     * @param _collateralToken Address del token colateral (ej: USDC)
     * @param _arsx Address del token ARSX
     * @param _aclManager Address del ACLManager
     * @param _feeBps Fee en basis points (bps). 100 bps = 1%
     * @param _redeemThreshold Umbral para limitar redenciones, ej: 0.95 * 1e18
     */
    constructor(
        address _collateralToken,
        address _arsx,
        address _aclManager,
        uint256 _feeBps,
        uint256 _redeemThreshold
    ) {
        if (_redeemThreshold > 1e18) revert PSM__RedeemThresholdTooHigh();
        collateralToken = IERC20(_collateralToken);
        arsx = ARSXStableCoin(_arsx);
        aclManager = ACLManager(_aclManager);
        feeBps = _feeBps;
        redeemThreshold = _redeemThreshold;
    }

    /**
     * @notice Actualizar el fee (en bps)
     */
    function setFee(uint256 newFeeBps) external {
        aclManager.checkConfigAdmin(msg.sender);
        feeBps = newFeeBps;
    }

    /**
     * @notice Actualizar el umbral máximo de redención
     * @param newThreshold Debe ser <= 1e18 (100%)
     */
    function setRedeemThreshold(uint256 newThreshold) external {
        aclManager.checkConfigAdmin(msg.sender);
        if (newThreshold > 1e18) revert PSM__RedeemThresholdTooHigh();
        redeemThreshold = newThreshold;
    }

    /**
     * @notice Swap de colateral a ARSX (mint)
     */
    function swapCollateralForARSX(uint256 collateralAmount) external {
        if (collateralAmount == 0) revert PSM__AmountMustBeMoreThanZero();

        uint256 fee = (collateralAmount * feeBps) / 10_000;
        uint256 netAmount = collateralAmount - fee;

        bool success = collateralToken.transferFrom(
            msg.sender,
            address(this),
            collateralAmount
        );
        if (!success) revert PSM__TransferFailed();

        bool minted = arsx.mint(msg.sender, netAmount);
        if (!minted) revert PSM__TransferFailed();
    }

    /**
     * @notice Swap de ARSX a colateral (burn)
     */
    function swapARSXForCollateral(uint256 arsxAmount) external {
        if (arsxAmount == 0) revert PSM__AmountMustBeMoreThanZero();

        uint256 fee = (arsxAmount * feeBps) / 10_000;
        uint256 netAmount = arsxAmount - fee;

        uint256 collateralBalance = collateralToken.balanceOf(address(this));
        uint256 maxRedeemable = (collateralBalance * redeemThreshold) / 1e18;

        if (netAmount > maxRedeemable) revert PSM__NotEnoughCollateral();

        bool success = arsx.transferFrom(msg.sender, address(this), arsxAmount);
        if (!success) revert PSM__TransferFailed();

        arsx.burn(arsxAmount);

        success = collateralToken.transfer(msg.sender, netAmount);
        if (!success) revert PSM__TransferFailed();
    }

    /**
     * @notice Retiro de emergencia
     */
    function withdrawCollateral(address to, uint256 amount) external {
        aclManager.checkEmergencyAdmin(msg.sender);
        collateralToken.transfer(to, amount);
    }
}
