// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {TokenManager} from "../src/TokenManager.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {ButterToken} from "../src/ButterToken.sol";

contract DeployTokenManager is Script {
    address mostRecentlyDeployedProtocolManager;
    TokenManager tokenManager;
    function run() external returns (address _tokenManager) {
        mostRecentlyDeployedProtocolManager = DevOpsTools
            .get_most_recent_deployment("ProtocolManager", block.chainid);

        vm.startBroadcast();
        tokenManager = new TokenManager(mostRecentlyDeployedProtocolManager);
        requestTokenListing();
        vm.stopBroadcast();
        _tokenManager = address(tokenManager);
        return _tokenManager;
    }

    function requestTokenListing() public {
        // address marketOwner = address(
        //     uint160(uint256(keccak256("marketOwner")))
        // );
        ButterToken butter = new ButterToken();
        // vm.startPrank(marketOwner);
        vm.deal(msg.sender, 6 ether);
        TokenManager(tokenManager).requestTokenListing{value: 1 ether}(
            address(butter)
        );
        // vm.stopPrank();
    }
}
