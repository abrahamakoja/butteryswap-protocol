// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {LimitMarket_v1} from "../../src/LimitMarket_v1.sol";
import {ButterToken} from "../../src/ButterToken.sol";

contract LimitMarketInteractions is Script{
 address  mostrecentlyDeployedLimitMarket;
 address  mostrecentlyDeployedJATToken;
  address   mostrecentlyDeployedButterToken ;
 function run() external{
    mostrecentlyDeployedLimitMarket = DevOpsTools.get_most_recent_deployment("LimitMarket_v1", block.chainid);
    mostrecentlyDeployedJATToken = DevOpsTools.get_most_recent_deployment("JATToken", block.chainid);
      mostrecentlyDeployedButterToken = DevOpsTools.get_most_recent_deployment("ButterToken", block.chainid);
  address mostrecentlyDeployed = DevOpsTools.get_most_recent_deployment("Enforcer_v1", block.chainid);

  updateContracts(payable(mostrecentlyDeployedLimitMarket),mostrecentlyDeployed);
  borrow(mostrecentlyDeployedLimitMarket,mostrecentlyDeployedJATToken);
}
function updateContracts(address _mostrecentlyDeployedLimitMarket, address token) public {
        vm.startBroadcast();
        LimitMarket_v1(payable(_mostrecentlyDeployedLimitMarket)).updateContracts(token);
        vm.stopBroadcast();
}

function borrow(address _mostrecentlyDeployedLimitMarket, address token) public {
    vm.startBroadcast();
      ButterToken(token).approve(payable(_mostrecentlyDeployedLimitMarket), 6660*10**18);
      LimitMarket_v1(payable(_mostrecentlyDeployedLimitMarket)).borrow(666*10**18,token);
    //  mostrecentlyDeployedJATToken.approve(address(mostrecentlyDeployedLimitMarket), 2333 * 10**mostrecentlyDeployedJATToken.decimals());
      vm.stopBroadcast();
}



}