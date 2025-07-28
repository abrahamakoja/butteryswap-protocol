// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {ProtocolManager} from "../src/ProtocolManager.sol";

contract DeployProtocolManager is Script {
    function run() external returns (address _ProtocolManager) {
        vm.startBroadcast();
        ProtocolManager protocolManager = new ProtocolManager();
        vm.stopBroadcast();
        _ProtocolManager =  address(protocolManager);
        return _ProtocolManager;
    }
}
