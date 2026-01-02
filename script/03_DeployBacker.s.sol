// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {Backer} from "../src/Backer.sol";
import {ProxyDevOpsTools} from "./ProxyDevOps.s.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployBacker is Script {
    address mostRecentlyDeployedProtocolManager;
    function run() external returns (Backer backer) {
        mostRecentlyDeployedProtocolManager = ProxyDevOpsTools
            .getMostRecentProxyDeployment(
                "ProtocolManager",
                "ERC1967Proxy",
                block.chainid
            );
        vm.startBroadcast();
        address proxy = Upgrades.deployUUPSProxy(
            "Backer.sol",
            abi.encodeCall(
                Backer.initialize,
                mostRecentlyDeployedProtocolManager
            )
        );

        vm.stopBroadcast();
        return Backer(proxy);
    }
}
