// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {LendRequestFactory} from "../src/LendRequestFactory.sol";
import {TokenManager} from "../src/TokenManager.sol";


contract DeployLendRequestFactory is Script {

    //  address protocolManager = DevOpsTools
    //         .get_most_recent_deployment("BorrowRequestFactory", block.chainid);

    
     
    function run() external returns (LendRequestFactory) {
        vm.startBroadcast();
        TokenManager tokenManager = new TokenManager();
        LendRequestFactory lendRequestFactory = new LendRequestFactory( address(tokenManager));
        vm.stopBroadcast();
        return lendRequestFactory;
    }
}

