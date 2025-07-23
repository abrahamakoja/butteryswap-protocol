// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {LendRequestFactory} from "../src/LendRequestFactory.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract DeployLendRequestFactory is Script {
    address mostRecentlyDeployedProtocolManager;

    function run() external returns (LendRequestFactory) {
        mostRecentlyDeployedProtocolManager = DevOpsTools
            .get_most_recent_deployment("ProtocolManager", block.chainid);
        vm.startBroadcast();

        LendRequestFactory lendRequestFactory = new LendRequestFactory(
            mostRecentlyDeployedProtocolManager
        );
        vm.stopBroadcast();
        return lendRequestFactory;
    }
}
