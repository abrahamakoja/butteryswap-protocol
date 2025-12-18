// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {BorrowRequest} from "../src/BorrowRequest.sol";
import {BorrowRequestFactory} from "../src/BorrowRequestFactory.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {IProtocolManager} from "../src/interfaces/IProtocolManager.sol";
contract DeployBorrowRequestFactory is Script {
    
    address mostRecentlyDeployedProtocolManager;
    UpgradeableBeacon beacon;
    function run()
        external
        returns (BorrowRequestFactory borrowRequestFactory)
    {
        mostRecentlyDeployedProtocolManager = DevOpsTools
            .get_most_recent_deployment("ProtocolManager", block.chainid);
        vm.startBroadcast();

        BorrowRequest implementation = new BorrowRequest();
        IProtocolManager(mostRecentlyDeployedProtocolManager)
            .setBorrowRequestImplementation(address(implementation));
        beacon = new UpgradeableBeacon(
            address(implementation),
            IProtocolManager(mostRecentlyDeployedProtocolManager).deployer()
        );

        address proxy = Upgrades.deployUUPSProxy(
            "BorrowRequestFactory.sol",
            abi.encodeCall(
                BorrowRequestFactory.initialize,
                (mostRecentlyDeployedProtocolManager, address(implementation))
            )
        );

        beacon.transferOwnership(proxy);

        vm.stopBroadcast();

        return BorrowRequestFactory(proxy);
    }
}
