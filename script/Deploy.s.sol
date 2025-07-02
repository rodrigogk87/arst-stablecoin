// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Script.sol";
import {ARSXStableCoin} from "../src/ARSXStableCoin.sol";
import {ARSXEngine} from "../src/ARSXEngine.sol";
import {IARSUSDTOracle} from "../src/interfaces/IARSUSDTOracle.sol";

/**
 * @title DeployARSX
 * @author Rodrigo Garcia Kosinski
 * @notice This script deploys ARSXStableCoin and ARSXEngine with example parameters
 */
contract DeployARSX is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY"); // PRIVATE_KEY debe ser un número decimal sin 0x

        vm.startBroadcast(pk);

        // Deploy ARSXStableCoin
        ARSXStableCoin arsxStableCoin = new ARSXStableCoin(msg.sender);

        // Example: Define allowed collateral tokens and price feeds
        address[] memory collateralTokens = new address[](1);
        address[] memory priceFeeds = new address[](1);

        // Example placeholder token and feed addresses — replace with real ones
        // e.g., WETH and Chainlink ETH/USD feed
        collateralTokens[0] = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9; // weth - sepolia
        priceFeeds[0] = 0x694AA1769357215DE4FAC081bf1f309aDC325306; //ETH/USD - sepolia

        // Example oracle address — replace with your deployed ARS/USDT Oracle - sepolia arsxOracleAddress
        address arsxOracleAddress = 0xadb97e76Cc79dB47D3Ea54AC0Bf125587E7019FC;

        // Deploy ARSXEngine
        ARSXEngine arsxEngine = new ARSXEngine(
            collateralTokens,
            priceFeeds,
            address(arsxStableCoin),
            arsxOracleAddress
        );

        // Transfer ARSXStableCoin ownership to ARSXEngine
        arsxStableCoin.transferOwnership(address(arsxEngine));

        vm.stopBroadcast();
    }
}
