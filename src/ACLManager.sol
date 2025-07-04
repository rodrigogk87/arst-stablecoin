// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title ACLManager
 * @author Rodrigo
 * @notice Central role and permission manager for ARSX system
 */
contract ACLManager is AccessControl {
    error ACLManager__NotPriceUpdater();
    error ACLManager__NotMinter();
    error ACLManager__NotBurner();
    error ACLManager__NotEmergencyAdmin();
    error ACLManager__NotRiskAdmin();
    error ACLManager__NotConfigAdmin();

    bytes32 public constant EMERGENCY_ADMIN_ROLE = keccak256("EMERGENCY_ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant PRICE_UPDATER_ROLE = keccak256("PRICE_UPDATER_ROLE");
    bytes32 public constant RISK_ADMIN_ROLE = keccak256("RISK_ADMIN_ROLE");
    bytes32 public constant CONFIG_ADMIN_ROLE = keccak256("CONFIG_ADMIN_ROLE");

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    // Price Updater
    function checkPriceUpdater(address user) external view {
        if (!hasRole(PRICE_UPDATER_ROLE, user)) {
            revert ACLManager__NotPriceUpdater();
        }
    }

    // Minter
    function checkMinter(address user) external view {
        if (!hasRole(MINTER_ROLE, user)) revert ACLManager__NotMinter();
    }

    // Burner
    function checkBurner(address user) external view {
        if (!hasRole(BURNER_ROLE, user)) revert ACLManager__NotBurner();
    }

    // Emergency Admin
    function checkEmergencyAdmin(address user) external view {
        if (!hasRole(EMERGENCY_ADMIN_ROLE, user)) {
            revert ACLManager__NotEmergencyAdmin();
        }
    }

    // Risk Admin
    function checkRiskAdmin(address user) external view {
        if (!hasRole(RISK_ADMIN_ROLE, user)) revert ACLManager__NotRiskAdmin();
    }

    // Config Admin
    function checkConfigAdmin(address user) external view {
        if (!hasRole(CONFIG_ADMIN_ROLE, user)) {
            revert ACLManager__NotConfigAdmin();
        }
    }
}
