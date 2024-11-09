// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {LimitMarket} from "../src/LimitMarket.sol";

contract DeployLimitMarket is Script {
    function run() external returns (LimitMarket) {
        vm.startBroadcast();
        LimitMarket limitMarket = new LimitMarket();
        vm.stopBroadcast();
        return limitMarket;
    }
}
