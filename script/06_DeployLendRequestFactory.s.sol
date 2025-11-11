// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {LendRequestFactory} from "../src/LendRequestFactory.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployLendRequestFactory is Script {
    address mostRecentlyDeployedProtocolManager;

    function run() external returns (LendRequestFactory) {
        mostRecentlyDeployedProtocolManager = DevOpsTools
            .get_most_recent_deployment("ProtocolManager", block.chainid);
        vm.startBroadcast();
        address proxy = Upgrades.deployUUPSProxy(
            "LendRequestFactory.sol",
            abi.encodeCall(
                LendRequestFactory.initialize,
                mostRecentlyDeployedProtocolManager
            )
        );

        vm.stopBroadcast();
        return LendRequestFactory(proxy);
    }
}
