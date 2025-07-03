// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Script.sol";
import {ARSXStableCoin} from "../src/ARSXStableCoin.sol";
import {ARSXEngine} from "../src/ARSXEngine.sol";
import {IARSUSDTOracle} from "../src/interfaces/IARSUSDTOracle.sol";

/**
 * @title DeployARSX
 * @author Rodrigo Garcia Kosinski
 * @notice This script deploys ARSXStableCoin and ARSXEngine using env vars per network
 */
contract DeployARSX is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY"); // PRIVATE_KEY sin 0x

        // Leer addresses dinámicamente
        address collateral = vm.envAddress("COLLATERAL");
        address priceFeed = vm.envAddress("PRICE_FEED");
        address oracleAddress = vm.envAddress("ORACLE_ADDRESS");

        vm.startBroadcast(pk);

        // Deploy ARSXStableCoin
        ARSXStableCoin arsxStableCoin = new ARSXStableCoin(msg.sender);

        // Example: Define allowed collateral tokens and price feeds
        address[] memory collateralTokens = new address[](1);
        address[] memory priceFeeds = new address[](1);

        collateralTokens[0] = collateral;
        priceFeeds[0] = priceFeed;

        // Deploy ARSXEngine
        ARSXEngine arsxEngine = new ARSXEngine(collateralTokens, priceFeeds, address(arsxStableCoin), oracleAddress);

        // Transfer ARSXStableCoin ownership to engine
        arsxStableCoin.transferOwnership(address(arsxEngine));

        console2.log("ARSXStableCoin deployed at:", address(arsxStableCoin));
        console2.log("ARSXEngine deployed at:", address(arsxEngine));

        vm.stopBroadcast();
    }
}

//./script/deploy.sh sepolia
//./script/deploy.sh arb_sepolia
