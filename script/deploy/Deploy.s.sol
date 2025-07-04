// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Script.sol";
import {ARSXStableCoin} from "src/ARSXStableCoin.sol";
import {ARSXEngine} from "src/ARSXEngine.sol";
import {IARSUSDTOracle} from "src/interfaces/IARSUSDTOracle.sol";
import {ACLManager} from "src/ACLManager.sol";
import {ARSUSDTOracle} from "src/ARSUSDTOracle.sol";

/**
 * @title DeployARSX
 * @author Rodrigo Garcia Kosinski
 * @notice Deploys ARSXStableCoin, ARSXEngine, and ACLManager using env vars per network
 */
contract DeployARSX is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        // Leer addresses dinámicamente
        address collateral = vm.envAddress("COLLATERAL");
        address priceFeed = vm.envAddress("PRICE_FEED");
        address oracleAddress = vm.envAddress("ORACLE_ADDRESS");

        vm.startBroadcast(pk);

        // Deploy ACLManager
        ACLManager aclManager = new ACLManager(msg.sender);

        // Deploy Oracle
        ARSUSDTOracle oracle = new ARSUSDTOracle(address(aclManager));

        // Deploy ARSXStableCoin with ACLManager
        ARSXStableCoin arsxStableCoin = new ARSXStableCoin(address(aclManager));

        // Setup arrays for collateral
        address[] memory collateralTokens = new address[](1);
        address[] memory priceFeeds = new address[](1);

        collateralTokens[0] = collateral;
        priceFeeds[0] = priceFeed;

        // Deploy ARSXEngine
        ARSXEngine arsxEngine =
            new ARSXEngine(collateralTokens, priceFeeds, address(arsxStableCoin), oracleAddress, address(aclManager));

        // Grant roles to ARSXEngine
        aclManager.grantRole(aclManager.MINTER_ROLE(), address(arsxEngine));
        aclManager.grantRole(aclManager.BURNER_ROLE(), address(arsxEngine));

        console2.log("ACLManager deployed at:", address(aclManager));
        console2.log("Oracle deployed at:", address(oracle));
        console2.log("ARSXStableCoin deployed at:", address(arsxStableCoin));
        console2.log("ARSXEngine deployed at:", address(arsxEngine));

        vm.stopBroadcast();
    }
}

// Ejemplos:
// forge script script/DeployARSX.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast -vvvv
