// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {LimitMarket} from "../src/LimitMarket.sol";
import {ProxyDevOps, ProxyDevOpsTools} from "./ProxyDevOps.s.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployLimitMarket is Script {
    address mostRecentlyDeployedProtocolManager;
    function run() external returns (LimitMarket limitMarket) {
        mostRecentlyDeployedProtocolManager = ProxyDevOpsTools
            .getMostRecentProxyDeployment(
                "ProtocolManager",
                "ERC1967Proxy",
                block.chainid
            );
        vm.startBroadcast();
        address proxy = Upgrades.deployUUPSProxy(
            "LimitMarket.sol",
            abi.encodeCall(
                LimitMarket.initialize,
                mostRecentlyDeployedProtocolManager
            )
        );
        console2.log(
            "limitMarket protocolManager",
            mostRecentlyDeployedProtocolManager
        );
        vm.stopBroadcast();
        return LimitMarket(proxy);
    }
}
