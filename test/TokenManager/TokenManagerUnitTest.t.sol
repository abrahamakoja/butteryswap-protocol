// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {deployContracts} from "../deployContracts.t.sol";

contract TokenManagerUnitTest is Test, deployContracts {
    function setUp() external {
        init();
    }

    function test_requestTokenListing() external {
        // tokenManager = deployTokenManager.run();
        // console2.log(address(tokenManager));
        // vm.startPrank(msg.sender);
        // deal(msg.sender, 6 ether);
        // tokenManager.requestTokenListing{value: 1 ether}(address(randomToken));
        // console2.log(address(tokenManager));
        // vm.stopPrank();
    }
}
