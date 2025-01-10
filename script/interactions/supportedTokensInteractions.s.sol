// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {SupportedTokens} from "../../src/SupportedTokens.sol";

contract supportedTokensInteractions is Script {
      address mostrecentlyDeployed;
      address mostrecentlyDeployedButterToken;
      address mostrecentlyDeployedJatToken;
    function run() external {
         mostrecentlyDeployed = DevOpsTools.get_most_recent_deployment("SupportedTokens", block.chainid);
         mostrecentlyDeployedButterToken = DevOpsTools.get_most_recent_deployment("ButterToken", block.chainid);
         mostrecentlyDeployedJatToken = DevOpsTools.get_most_recent_deployment("JATToken", block.chainid);
        approveTokenRequest(payable(mostrecentlyDeployed));
        approveTokenRequest(payable(mostrecentlyDeployed));
        delistToken(payable(mostrecentlyDeployed));
        delistToken(payable(mostrecentlyDeployed));
    }

    function approveTokenRequest(address _mostrecentlyDeployed) public {
        vm.startBroadcast();
        SupportedTokens(payable(_mostrecentlyDeployed)).approveTokenRequest(0);
        vm.stopBroadcast();
    }
    function delistToken(address _mostrecentlyDeployed) public {
        vm.startBroadcast();
        SupportedTokens(payable(_mostrecentlyDeployed)).delistToken(address(mostrecentlyDeployedJatToken));
        vm.stopBroadcast();
    }
}   