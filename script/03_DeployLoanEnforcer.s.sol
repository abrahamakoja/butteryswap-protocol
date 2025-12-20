// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {LoanEnforcer} from "../src/LoanEnforcer.sol";
import {ProxyDevOpsTools} from "./ProxyDevOps.s.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployLoanEnforcer is Script {
    address mostRecentlyDeployedProtocolManager;
    function run() external returns (LoanEnforcer) {
        mostRecentlyDeployedProtocolManager = ProxyDevOpsTools
            .getMostRecentProxyDeployment(
                "ProtocolManager",
                "ERC1967Proxy",
                block.chainid
            );
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
