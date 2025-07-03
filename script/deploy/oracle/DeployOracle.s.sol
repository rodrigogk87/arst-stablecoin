// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {ARSUSDTOracle} from "src/ARSUSDTOracle.sol";

contract DeployOracle is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);

        ARSUSDTOracle oracle = new ARSUSDTOracle();

        console2.log("Oracle deployed at:", address(oracle));

        vm.stopBroadcast();
    }
}

//0xB3494B032cBCB533EAa4980d56e6a9B882f54aD6
