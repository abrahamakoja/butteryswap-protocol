// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {ProtocolManager} from "../src/ProtocolManager.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployProtocolManager is Script {
    function run() public {
        console2.log("this ran");
        vm.startBroadcast();
        address proxy = Upgrades.deployUUPSProxy(
            "ProtocolManager.sol",
            abi.encodeCall(ProtocolManager.initialize, ())
        );

        vm.stopBroadcast();
    }
}
