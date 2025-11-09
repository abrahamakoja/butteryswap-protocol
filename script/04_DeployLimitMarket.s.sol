// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {LimitMarket} from "../src/LimitMarket.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract DeployLimitMarket is Script {
    address mostRecentlyDeployedProtocolManager;
    function run() external returns (LimitMarket limitMarket) {
        mostRecentlyDeployedProtocolManager = DevOpsTools
            .get_most_recent_deployment("ProtocolManager", block.chainid);
        vm.startBroadcast();
        limitMarket = new LimitMarket(mostRecentlyDeployedProtocolManager);
        vm.stopBroadcast();
        return limitMarket;
    }
}
