// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {RandomTokens} from "../src/RandomTokens.sol";

contract DeployRandomTokens is Script {
    function run(
        string memory name,
        string memory symbol,
        uint256 initialMint
    ) external returns (RandomTokens) {
        vm.startBroadcast();
        RandomTokens randomTokens = new RandomTokens(name, symbol, initialMint);
        vm.stopBroadcast();
        return randomTokens;
    }
}
