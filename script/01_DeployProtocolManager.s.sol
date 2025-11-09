// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {ProtocolManager} from "../src/ProtocolManager.sol";

contract DeployProtocolManager is Script {
    function run() external returns (ProtocolManager protocolManager) {
        vm.startBroadcast();
        protocolManager = new ProtocolManager();
        // console2.log("script ProtocolManager contract", address(this));
        console2.log("deployer script", address(protocolManager));
        vm.stopBroadcast();
        return protocolManager;
    }
}
