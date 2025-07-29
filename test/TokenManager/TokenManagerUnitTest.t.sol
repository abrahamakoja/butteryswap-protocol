// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {TokenManager} from "../../src/TokenManager.sol";
import {DeployProtocolManager} from "../../script/01_DeployProtocolManager.s.sol";
import {DeployTokenManager} from "../../script/02_DeployTokenManager.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract TokenManagerUnitTest is Test {
    DeployProtocolManager deployProtocolManager;
    DeployTokenManager deployTokenManager;
    address public protocolManager;
    address public tokenManager;
    address public marketOwner;
    function setUp() public {
        // deployProtocolManager = new DeployProtocolManager();
        deployTokenManager = new DeployTokenManager();
        // protocolManager = deployProtocolManager.run();
        tokenManager = deployTokenManager.run();
        console2.log("setup ran");
    }

    function test_requestTokenListing() public {
        // marketOwner = address(uint160(uint256(keccak256("marketOwner"))));
        // ERC20Mock randomToken = new ERC20Mock(
        //     "randomToken",
        //     "RAND",
        //     marketOwner,
        //     UINT256_MAX
        // );
        // vm.startPrank(msg.sender);
        // vm.deal(msg.sender, 6 ether);
        // // TokenManager(tokenManager).requestTokenListing{value: 1 ether}(address(randomToken));
        // vm.stopPrank();
    }
}
