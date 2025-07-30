// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script,console2} from "forge-std/Script.sol";
import {TokenManager} from "../src/TokenManager.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract DeployTokenManager is Script {
    function run() external returns (TokenManager tokenManager) {
        address mostRecentlyDeployedProtocolManager = DevOpsTools
            .get_most_recent_deployment("ProtocolManager", block.chainid);

        vm.startBroadcast();
        tokenManager = new TokenManager(mostRecentlyDeployedProtocolManager);
        console2.log("Deploy script",address(tokenManager));
        vm.stopBroadcast();
        return tokenManager;
    }
}
