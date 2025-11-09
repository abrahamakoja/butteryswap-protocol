// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {BorrowRequestFactory} from "../src/BorrowRequestFactory.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
contract DeployBorrowRequestFactory is Script {
    address mostRecentlyDeployedProtocolManager;

    function run()
        external
        returns (BorrowRequestFactory borrowRequestFactory)
    {
        mostRecentlyDeployedProtocolManager = DevOpsTools
            .get_most_recent_deployment("ProtocolManager", block.chainid);
        vm.startBroadcast();

        address proxy = Upgrades.deployUUPSProxy(
            "BorrowRequestFactory.sol",
            abi.encodeCall(
                BorrowRequestFactory.initialize,
                mostRecentlyDeployedProtocolManager
            )
        );

        vm.stopBroadcast();

        return BorrowRequestFactory(proxy);
    }
}
