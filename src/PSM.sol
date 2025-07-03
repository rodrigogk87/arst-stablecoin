// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ARSXStableCoin} from "./ARSXStableCoin.sol";

contract PSM is Ownable {
    error PSM__AmountMustBeMoreThanZero();
    error PSM__TransferFailed();
    error PSM__NotEnoughARSX();

    IERC20 public immutable collateralToken;
    ARSXStableCoin public immutable arsx;
    uint256 public feeBps; // e.g., 30 = 0.3%

    constructor(
        address _collateralToken,
        address _arsx,
        uint256 _feeBps
    ) Ownable(msg.sender) {
        collateralToken = IERC20(_collateralToken);
        arsx = ARSXStableCoin(_arsx);
        feeBps = _feeBps;
    }

    function setFee(uint256 newFeeBps) external onlyOwner {
        feeBps = newFeeBps;
    }

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

    function swapARSXForCollateral(uint256 arsxAmount) external {
        if (arsxAmount == 0) revert PSM__AmountMustBeMoreThanZero();

        uint256 fee = (arsxAmount * feeBps) / 10_000;
        uint256 netAmount = arsxAmount - fee;

        uint256 collateralBalance = collateralToken.balanceOf(address(this));
        if (netAmount > collateralBalance) revert PSM__NotEnoughARSX();

        bool success = arsx.transferFrom(msg.sender, address(this), arsxAmount);
        if (!success) revert PSM__TransferFailed();

        arsx.burn(arsxAmount);

        success = collateralToken.transfer(msg.sender, netAmount);
        if (!success) revert PSM__TransferFailed();
    }

    // Emergency withdrawal
    function withdrawCollateral(address to, uint256 amount) external onlyOwner {
        collateralToken.transfer(to, amount);
    }
}
