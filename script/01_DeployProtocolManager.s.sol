// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {ProtocolManager} from "../src/ProtocolManager.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployProtocolManager is Script {
    function run() external returns (ProtocolManager protocolManager) {
        console2.log("this ran");

        vm.startBroadcast();

        address proxy = Upgrades.deployUUPSProxy(
            "ProtocolManager.sol",
            abi.encodeCall(ProtocolManager.initialize, ())
        );

        vm.stopBroadcast();

        console2.log(
            "script deployer",
            address(ProtocolManager(proxy).deployer())
        );
        console2.log("script proxy", address(proxy));

        return ProtocolManager(proxy);
    }
}
