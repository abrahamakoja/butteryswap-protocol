// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {BorrowRequestFactory} from "../src/BorrowRequestFactory.sol";
import {DeployProtocolManager} from "../../script/01_DeployProtocolManager.s.sol";
import {DeployBorrowRequestFactory} from "../../script/05_DeployBorrowRequestFactory.s.sol";

contract BorrowRequestFactoryUnitTest is Test {
    DeployProtocolManager deployProtocolManager;
    DeployBorrowRequestFactory deployBorrowRequestFactory;
    address public protocolManager;
    address public borrowRequestFactory;
    function setUp() public {
        deployProtocolManager = new DeployProtocolManager();
        deployBorrowRequestFactory = new DeployBorrowRequestFactory();
        protocolManager = deployProtocolManager.run();
        borrowRequestFactory = deployBorrowRequestFactory.run();
    }
}
