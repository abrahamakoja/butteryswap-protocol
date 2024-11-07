// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {Enforcer_v1} from "../src/Enforcer_v1.sol";

contract DeployEnforcer_v1 is Script {
    function run() external returns (Enforcer_v1) {
        vm.startBroadcast();
        Enforcer_v1 enforcer_v1 = new Enforcer_v1();
        vm.stopBroadcast();
        return enforcer_v1;
    }
}
