// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {SupportedTokens} from "../src/SupportedTokens.sol";
import {JATToken} from "../src/otherToken.sol";
import {DeployButterToken} from "../script/DeployButterToken.s.sol";
import {DeployotherToken} from "../script/DeployotherToken.s.sol";
import {ButterToken} from "../src/ButterToken.sol";

contract DeploySupportedTokens is Script {
    function run() external returns (SupportedTokens) {
        vm.startBroadcast();
        SupportedTokens  supportedTokens = new SupportedTokens();

        // DeployButterToken deployButterToken = new DeployButterToken();
        ButterToken butterToken = new ButterToken();

        // DeployotherToken deployotherToken = new DeployotherToken();
        JATToken jATToken = new JATToken();
        supportedTokens.requestTokenListing{value: 10 ether}(address(jATToken));
        supportedTokens.requestTokenListing{value: 20 ether}(address(butterToken));
        vm.stopBroadcast();
        return supportedTokens;
    }

}
