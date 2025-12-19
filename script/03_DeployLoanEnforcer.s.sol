// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {LoanEnforcer} from "../src/LoanEnforcer.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployLoanEnforcer is Script {
    address mostRecentlyDeployedProtocolManager;
    function run() external returns (LoanEnforcer) {
        mostRecentlyDeployedProtocolManager = DevOpsTools
            .get_most_recent_deployment("ERC1967Proxy", block.chainid);
        vm.startBroadcast();
        address proxy = Upgrades.deployUUPSProxy(
            "LoanEnforcer.sol",
            abi.encodeCall(
                LoanEnforcer.initialize,
                mostRecentlyDeployedProtocolManager
            )
        );

        vm.stopBroadcast();
        return LoanEnforcer(proxy);
    }
}
