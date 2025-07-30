// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script,console2} from "forge-std/Script.sol";
import {TokenManager} from "../src/TokenManager.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract DeployTokenManager is Script {
    function run() external returns (TokenManager tokenManager) {
        vm.startBroadcast();
        // address mostRecentlyDeployedProtocolManager = DevOpsTools
        //     .get_most_recent_deployment("ProtocolManager", block.chainid);

        // tokenManager = new TokenManager(mostRecentlyDeployedProtocolManager);
        tokenManager = new TokenManager(address(0x34A1D3fff3958843C43aD80F30b94c510645C316));
        console2.log("Deploy script",address(tokenManager));
        vm.stopBroadcast();
        return tokenManager;
    }
}
