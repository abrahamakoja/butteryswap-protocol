// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {Butter} from "../src/Butter.sol";

contract DeployButterToken is Script {
    function run() external returns (Butter) {
        vm.startBroadcast();
        Butter butter = new Butter();
        vm.stopBroadcast();
        return butter;
    }
}
