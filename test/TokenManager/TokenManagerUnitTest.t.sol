// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {deployContractsOnLocalChain} from "../deployment/deployContractsOnLocalChain.t.sol";

contract TokenManagerUnitTest is Test, deployContractsOnLocalChain {
    event tokenListingRequestCreated(
        address indexed tokenAddress,
        uint256 indexed tokenIndex
    );
    event tokenListed(address indexed listedTokenAddress);
    event tokenUnListingRequested(address indexed deListedTokenAddress);
    event tokenUnListed(address indexed deListedTokenAddress);
    event tokenFeeAddressUpdated(
        address indexed token,
        address indexed oldFeeAddress,
        address indexed newFeeAddress
    );

    function setUp() external {
        init();
    }

    function test_requestTokenListing() external {
        vm.startPrank(msg.sender);
        // deal(msg.sender, 6 ether);
        // vm.expectEmit();
        // emit tokenListingRequestCreated(
        //     address(randomToken),
        //     tokenManager.getTotalRequestedTokens() + 1
        // );
        // tokenManager.requestTokenListing{value: 1 ether}(address(randomToken));
        // console2.log(address(tokenManager));

        vm.stopPrank();
    }
}
