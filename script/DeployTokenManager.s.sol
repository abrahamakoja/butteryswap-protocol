// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {TokenManager} from "../src/TokenManager.sol";
import {JATToken} from "../src/otherToken.sol";
import {ButterToken} from "../src/ButterToken.sol";

contract DeployTokenManager is Script {
    function run() external returns (TokenManager, ButterToken, JATToken) {
        vm.startBroadcast();
        TokenManager tokenManager = new TokenManager();
        ButterToken butterToken = new ButterToken();
        JATToken jATToken = new JATToken();
        vm.stopBroadcast();
        return (tokenManager, butterToken, jATToken);
    }
}
