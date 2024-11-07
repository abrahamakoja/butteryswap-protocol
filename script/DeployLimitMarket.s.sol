// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {LimitMarket_v1} from "../src/LimitMarket_v1.sol";
import { console} from "forge-std/Test.sol";

contract DeployLimitMarket is Script {
    function run(/*address enforcer, address token*/) external returns (LimitMarket_v1) {
        vm.startBroadcast();
        LimitMarket_v1 limitMarket = new LimitMarket_v1();
        // limitMarket.updateContracts(enforcer,token);
        //  console.log("msg dot sender",address(msg.sender));
        //  console.log("token",limitMarket.getTokenContractAddress());
        //  console.log("token direct",token);
        //  console.log("enforcer direct",enforcer);
        vm.stopBroadcast();
        return limitMarket; 
    }
}
