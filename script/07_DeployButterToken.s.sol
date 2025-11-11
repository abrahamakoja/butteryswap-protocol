// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {ButterToken} from "../src/ButterToken.sol";

contract DeployButterToken is Script {
    function run() external returns (ButterToken) {
        vm.startBroadcast();
        ButterToken butterToken = new ButterToken();
        vm.stopBroadcast();
        return butterToken;
    }
}
