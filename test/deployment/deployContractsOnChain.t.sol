// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {TokenManager} from "../../src/TokenManager.sol";
import {ProtocolManager} from "../../src/ProtocolManager.sol";
import {IProtocolManager} from "../../src/interfaces/IProtocolManager.sol";
import {ITokenManager} from "../../src/interfaces/ITokenManager.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
abstract contract deployContractsOnChain is Test {
    ProtocolManager internal protocolManager;
    IProtocolManager internal iProtocolManager;

    ITokenManager internal iTokenManager;
    TokenManager internal tokenManager;

    ERC20Mock internal randomToken;

    function init() public {
        // protocolManager = new ProtocolManager();
        // console2.log("test protocolManager", address(protocolManager));
        // tokenManager = new TokenManager(address(protocolManager));
        // console2.log("test tokenManager", address(tokenManager));
        // iTokenManager = ITokenManager(address(tokenManager));
        // iProtocolManager = IProtocolManager(address(protocolManager));
        // randomToken = new ERC20Mock("random", "RAND", msg.sender, UINT256_MAX);
    }
}
