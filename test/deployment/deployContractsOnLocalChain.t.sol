// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {TokenManager} from "../../src/TokenManager.sol";
import {ProtocolManager} from "../../src/ProtocolManager.sol";
import {IProtocolManager} from "../../src/interfaces/IProtocolManager.sol";
// import {ITokenManager} from "../../src/interfaces/ITokenManager.sol";
import {BorrowRequestFactory} from "../../src/BorrowRequestFactory.sol";
import {LimitMarket} from "../../src/LimitMarket.sol";
import {ILimitMarket} from "../../src/interfaces/ILimitMarket.sol";
// import {TokenManager} from "../../src/TokenManager.sol";
import {ITokenManager} from "../../src/interfaces/ITokenManager.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
abstract contract deployContractsOnLocalChain is Test {
    // ProtocolManager public protocolManager;
    IProtocolManager public protocolManager;
    ILimitMarket limitMarket;
    ITokenManager internal iTokenManager;
    TokenManager internal tokenManager;

    ERC20Mock internal randomToken;

    function init() public {
        // deploy protocol manager
        // ProtocolManager _protocolManager = new ProtocolManager();
        // protocolManager = IProtocolManager(address(_protocolManager));
        // // deploy limit Market
        // LimitMarket _limitMarket = new LimitMarket(address(protocolManager));
        // limitMarket = ILimitMarket(address(_limitMarket));
        // address proxy = Upgrades.deployUUPSProxy(
        //     "BorrowRequestFactory.sol",
        //     abi.encodeCall(
        //         BorrowRequestFactory.initialize,
        //         address(protocolManager)
        //     )
        // );
        // BorrowRequestFactory _borrowRequestFactory = BorrowRequestFactory(
        //     proxy
        // );
        // borrowRequestFactory = _borrowRequestFactory;
        // console2.log("test protocolManager", address(protocolManager));
        // tokenManager = new TokenManager(address(protocolManager));
        // console2.log("test tokenManager", address(tokenManager));
        // iTokenManager = ITokenManager(address(tokenManager));
        // iProtocolManager = IProtocolManager(address(protocolManager));
        // randomToken = new ERC20Mock("random", "RAND", msg.sender, UINT256_MAX);
    }
}
