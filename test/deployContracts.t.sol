// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {TokenManager} from "../src/TokenManager.sol";
import {ProtocolManager} from "../src/ProtocolManager.sol";
import {IProtocolManager} from "../src/interfaces/IProtocolManager.sol";
import {ITokenManager} from "../src/interfaces/ITokenManager.sol";
import {DeployProtocolManager} from "../script/01_DeployProtocolManager.s.sol";
import {DeployTokenManager} from "../script/02_DeployTokenManager.s.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
abstract contract deployContracts is Test {
    DeployProtocolManager internal deployProtocolManager;
    DeployTokenManager internal deployTokenManager;
    ITokenManager internal iTokenManager;
    ProtocolManager internal protocolManager;
    TokenManager internal tokenManager;
    IProtocolManager internal iProtocolManager;

    // ERC20Mock randomToken;

    function init() public {
        deployProtocolManager = new DeployProtocolManager();

        deployTokenManager = new DeployTokenManager();

        protocolManager = deployProtocolManager.run();

        // tokenManager = deployTokenManager.run();

        // iTokenManager = ITokenManager(address(tokenManager));

        iProtocolManager = IProtocolManager(address(protocolManager));
    }
}
