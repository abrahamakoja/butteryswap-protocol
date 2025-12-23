// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {Backery} from "../src/Backery.sol";
import {ProxyDevOpsTools} from "./ProxyDevOps.s.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployBackery is Script {
    address mostRecentlyDeployedProtocolManager;

    function run() external returns (Backery backery) {
        mostRecentlyDeployedProtocolManager = ProxyDevOpsTools
            .getMostRecentProxyDeployment(
                "ProtocolManager",
                "ERC1967Proxy",
                block.chainid
            );
        vm.startBroadcast();
        address proxy = Upgrades.deployUUPSProxy(
            "Backery.sol",
            abi.encodeCall(
                Backery.initialize,
                mostRecentlyDeployedProtocolManager
            )
        );

        vm.stopBroadcast();
        return Backery(proxy);
    }
}
