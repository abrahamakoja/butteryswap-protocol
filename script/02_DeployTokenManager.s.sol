// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {TokenManager} from "../src/TokenManager.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployTokenManager is Script {
    function run() external returns (TokenManager tokenManager) {
        address mostRecentlyDeployedProtocolManager = DevOpsTools
            .get_most_recent_deployment("ProtocolManager", block.chainid);

        vm.startBroadcast();

        address proxy = Upgrades.deployUUPSProxy(
            "TokenManager.sol",
            abi.encodeCall(
                TokenManager.initialize,
                mostRecentlyDeployedProtocolManager
            )
        );

        vm.stopBroadcast();
        return TokenManager(proxy);
    }
}
