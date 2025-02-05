// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {LimitMarket_v1} from "../src/LimitMarket_v1.sol";
import {BorrowRequestFactory} from "../src/BorrowRequestFactory.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";


contract DeployLimitMarket is Script {
    function run() external returns (LimitMarket_v1) {

      address   mostrecentlyBorrowRequestFactory = DevOpsTools.get_most_recent_deployment(
            "BorrowRequestFactory",
            block.chainid
        );
        vm.startBroadcast();

        LimitMarket_v1 limitMarket = new LimitMarket_v1(address(mostrecentlyBorrowRequestFactory));
        // limitMarket.updateContracts(enforcer,token);
        vm.stopBroadcast();
        return limitMarket; 
    }
} 
 