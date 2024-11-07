// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {ButterToken} from "../src/ButterToken.sol";

contract DeployButterToken is Script {
    function run(address limitMarket_v1,address USER) external returns (ButterToken) {
        vm.startBroadcast();
        ButterToken butterToken = new ButterToken();
        //  vm.prank(address(msg.sender)); // Simulate token deployment from deployer
    butterToken.transfer(address(limitMarket_v1), 666 * 10**butterToken.decimals());
    butterToken.transfer(address(USER), 2666 * 10**butterToken.decimals());
   
    
        vm.stopBroadcast();
        return butterToken;
    }
}
