// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {JATToken} from "../src/otherToken.sol";

contract DeployotherToken is Script {
    function run() external returns (JATToken) {
        vm.startBroadcast();
        JATToken jATToken = new JATToken();
        //  vm.prank(address(msg.sender)); // Simulate token deployment from deployer
    // butterToken.transfer(address(limitMarket_v1), 666 * 10**butterToken.decimals());
    // butterToken.transfer(address(USER), 2666 * 10**butterToken.decimals());
   
    
        vm.stopBroadcast();
        return jATToken;
    }
}
