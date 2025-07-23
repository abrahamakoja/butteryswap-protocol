// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {TokenManager} from "../src/TokenManager.sol";

contract DeployTokenManager is Script {
    function run() external returns (TokenManager) {
        vm.startBroadcast();
        TokenManager tokenManager = new TokenManager();
        vm.stopBroadcast();
        return tokenManager;
    }
}
