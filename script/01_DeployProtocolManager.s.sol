// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {ProtocolManager} from "../src/ProtocolManager.sol";

contract DeployProtocolManager is Script {
    function run() external returns (ProtocolManager) {
        vm.startBroadcast();
        ProtocolManager protocolManager = new ProtocolManager();
        vm.stopBroadcast();
        return protocolManager;
    }
}
