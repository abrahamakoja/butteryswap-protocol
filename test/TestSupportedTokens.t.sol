// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {SupportedTokens} from "../../src/SupportedTokens.sol";
import {DeploySupportedTokens} from "../../script/DeploySupportedTokens.s.sol";
import {supportedTokensInteractions} from "../../script/interactions/supportedTokensInteractions.s.sol";
import {ERC20} from "./mocks/ERC20Mock.sol";

contract TestSupportedTokens is Test {
    function  setUp() external {
        
        supportedTokensInteractions deploySupportedTokens;
        deploySupportedTokens = new supportedTokensInteractions();
        deploySupportedTokens.run();
    }

    function testRequestTokenListing() public {

    }
}
