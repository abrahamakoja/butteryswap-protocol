// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {LoanEnforcer} from "../src/LoanEnforcer.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract DeployLoanEnforcer is Script {
    address mostRecentlyDeployedProtocolManager;
    function run() external returns (LoanEnforcer) {
        mostRecentlyDeployedProtocolManager = DevOpsTools
            .get_most_recent_deployment("ProtocolManager", block.chainid);
        vm.startBroadcast();
        LoanEnforcer loanEnforcer = new LoanEnforcer(
            mostRecentlyDeployedProtocolManager
        );
        vm.stopBroadcast();
        return loanEnforcer;
    }
}
