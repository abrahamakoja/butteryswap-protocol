// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {BorrowRequest} from "../src/BorrowRequest.sol";
import {LoanManager} from "../src/LoanManager.sol";
import {ProxyDevOpsTools} from "./ProxyDevOps.s.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {IProtocolManager} from "../src/interfaces/IProtocolManager.sol";

contract DeployLoanManager is Script {
    address mostRecentlyDeployedProtocolManager;
    UpgradeableBeacon beacon;
    function run() external returns (LoanManager loanManager) {
        mostRecentlyDeployedProtocolManager = ProxyDevOpsTools
            .getMostRecentProxyDeployment(
                "ProtocolManager",
                "ERC1967Proxy",
                block.chainid
            );

        vm.startBroadcast();

        BorrowRequest implementation = new BorrowRequest();

        beacon = new UpgradeableBeacon(
            address(implementation),
            IProtocolManager(mostRecentlyDeployedProtocolManager).deployer()
        );

        address proxy = Upgrades.deployUUPSProxy(
            "LoanManager.sol",
            abi.encodeCall(
                LoanManager.initialize,
                (mostRecentlyDeployedProtocolManager, address(implementation))
            )
        );

        beacon.transferOwnership(proxy);

        vm.stopBroadcast();

        return LoanManager(proxy);
    }
}
