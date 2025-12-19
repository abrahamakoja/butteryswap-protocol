// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {BorrowRequest} from "../src/BorrowRequest.sol";
import {LoanManager} from "../src/LoanManager.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {IProtocolManager} from "../src/interfaces/IProtocolManager.sol";

import {ProtocolManager} from "../src/ProtocolManager.sol";
contract DeployLoanManager is Script {
    address mostRecentlyDeployedProtocolManager;
    UpgradeableBeacon beacon;
    function run() external /* returns (LoanManager loanManager)*/ {
        mostRecentlyDeployedProtocolManager = DevOpsTools
            .get_most_recent_deployment("ERC1967Proxy", block.chainid);
        vm.startBroadcast();

        // LoanManager implementation = new LoanManager();
        // IProtocolManager(mostRecentlyDeployedProtocolManager)
        //     .setLoanManagerImplementationAddress(
        //         address(implementation),
        //         msg.sender
        //     );
        // beacon = new UpgradeableBeacon(
        //     address(implementation),
        //     IProtocolManager(mostRecentlyDeployedProtocolManager).deployer()
        // );

        address deployer = ProtocolManager(mostRecentlyDeployedProtocolManager)
            .deployer();

        console2.log(address(deployer));
        console2.log(
            "protocolManager",
            address(mostRecentlyDeployedProtocolManager)
        );

        // address proxy = Upgrades.deployUUPSProxy(
        //     "LoanManager.sol",
        //     abi.encodeCall(
        //         LoanManager.initialize,
        //         (mostRecentlyDeployedProtocolManager, address(implementation))
        //     )
        // );

        // beacon.transferOwnership(proxy);

        vm.stopBroadcast();

        // return LoanManager(proxy);
    }
}
