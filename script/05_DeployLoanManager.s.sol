// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {LoanManager} from "../src/LoanManager.sol";
import {ProxyDevOpsTools} from "./ProxyDevOps.s.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {IProtocolManager} from "../src/interfaces/IProtocolManager.sol";

contract DeployLoanManager is Script {
    address mostRecentlyDeployedProtocolManager;

    function run() external returns (LoanManager loanManager) {
        mostRecentlyDeployedProtocolManager = ProxyDevOpsTools
            .getMostRecentProxyDeployment(
                "ProtocolManager",
                "ERC1967Proxy",
                block.chainid
            );

        vm.startBroadcast();

        address proxy = Upgrades.deployUUPSProxy(
            "LoanManager.sol",
            abi.encodeCall(
                LoanManager.initialize,
                (mostRecentlyDeployedProtocolManager)
            )
        );

        vm.stopBroadcast();

        return LoanManager(payable(address(proxy)));
    }
}
