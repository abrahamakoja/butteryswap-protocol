// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {ProtocolManager} from "../src/ProtocolManager.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployProtocolManager is Script {
    function run() external returns (ProtocolManager protocolManager) {
        vm.startBroadcast();
        address proxy = Upgrades.deployUUPSProxy(
            "ProtocolManager.sol",
            abi.encodeCall(ProtocolManager.initialize, ())
        );

        vm.stopBroadcast();
        return ProtocolManager(proxy);
    }
}
