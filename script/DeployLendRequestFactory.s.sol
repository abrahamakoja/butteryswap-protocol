// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {LendRequestFactory} from "../src/LendRequestFactory.sol";

contract DeployLendRequestFactory is Script {

     address mostrecentlyDeployedST;
     
    function run() external returns (LendRequestFactory) {
        vm.startBroadcast();
        LendRequestFactory lendRequestFactory = new LendRequestFactory();
        vm.stopBroadcast();
        return lendRequestFactory;
    }
}

