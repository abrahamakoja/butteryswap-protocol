// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {BorrowRequestFactory} from "../src/BorrowRequestFactory.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract DeployBorrowRequestFactory is Script {
    address mostRecentlyDeployedProtocolManager;

    function run() external returns (address _BorrowRequestFactory) {
        mostRecentlyDeployedProtocolManager = DevOpsTools
            .get_most_recent_deployment("ProtocolManager", block.chainid);
        vm.startBroadcast();
        BorrowRequestFactory borrowRequestFactory = new BorrowRequestFactory(
            mostRecentlyDeployedProtocolManager
        );
        vm.stopBroadcast();
        _BorrowRequestFactory = address(borrowRequestFactory);
        return _BorrowRequestFactory;
    }
}
