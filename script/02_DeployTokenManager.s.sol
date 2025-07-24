// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {TokenManager} from "../src/TokenManager.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract DeployTokenManager is Script {
    address mostRecentlyDeployedProtocolManager;
    function run() external returns (TokenManager) {
        mostRecentlyDeployedProtocolManager = DevOpsTools
            .get_most_recent_deployment("ProtocolManager", block.chainid);
        vm.startBroadcast();
        TokenManager tokenManager = new TokenManager(
            mostRecentlyDeployedProtocolManager
        );
        vm.stopBroadcast();
        return tokenManager;
    }
}
