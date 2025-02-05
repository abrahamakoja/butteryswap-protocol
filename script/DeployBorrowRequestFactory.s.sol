// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {BorrowRequestFactory} from "../src/BorrowRequestFactory.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract DeployBorrowRequestFactory is Script {

     address mostrecentlyDeployedST;
     
    function run() external returns (BorrowRequestFactory) {

         mostrecentlyDeployedST = DevOpsTools.get_most_recent_deployment(
            "SupportedTokens",
            block.chainid
        );
        vm.startBroadcast();
        BorrowRequestFactory borrowRequestFactory = new BorrowRequestFactory(address(mostrecentlyDeployedST));
        vm.stopBroadcast();
        return borrowRequestFactory;
    }
}

