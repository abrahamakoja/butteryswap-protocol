// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {LimitMarket_v1} from "../src/LimitMarket_v1.sol";

contract DeployLimitMarket is Script { 

    function run() external returns (LimitMarket_v1) {
        vm.startBroadcast();
        LimitMarket_v1 limitMarket = new LimitMarket_v1();
        vm.stopBroadcast();
        return limitMarket;
    }
}
