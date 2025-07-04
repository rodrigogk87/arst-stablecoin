// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

pragma solidity 0.8.20;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ACLManager} from "./ACLManager.sol";

/*
 * @title ARSXStableCoin
 * @author Rodrigo Garcia Kosinski
 * Collateral: Exogenous
 * Minting (Stability Mechanism): Decentralized (Algorithmic)
 * Value (Relative Stability): Anchored (Pegged to Ars peso)
 * Collateral Type: Crypto
 *
* This is the contract meant to be owned by ARSXEngine. It is a ERC20 token that can be minted and burned by the
ARSXEngine smart contract.
 */
contract ARSXStableCoin is ERC20Burnable {
    error ARSXStableCoin__AmountMustBeMoreThanZero();
    error ARSXStableCoin__BurnAmountExceedsBalance();
    error ARSXStableCoin__NotZeroAddress();

    ACLManager public aclManager;

    constructor(address _aclManager) ERC20("ARSXStableCoin", "ARSX") {
        aclManager = ACLManager(_aclManager);
    }

    function burn(uint256 _amount) public override {
        aclManager.checkBurner(msg.sender);

        uint256 balance = balanceOf(msg.sender);
        if (_amount == 0) revert ARSXStableCoin__AmountMustBeMoreThanZero();
        if (balance < _amount) {
            revert ARSXStableCoin__BurnAmountExceedsBalance();
        }

        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external returns (bool) {
        aclManager.checkMinter(msg.sender);

        if (_to == address(0)) revert ARSXStableCoin__NotZeroAddress();
        if (_amount == 0) revert ARSXStableCoin__AmountMustBeMoreThanZero();

        _mint(_to, _amount);
        return true;
    }
}
