// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {erc20TokenLibrary} from "../../src/libraries/erc20TokenLibrary.sol";
import {ProtocolManager} from "../../src/ProtocolManager.sol";
import {BorrowRequestFactory} from "../../src/BorrowRequestFactory.sol";
import {LimitMarket} from "../../src/LimitMarket.sol";
import {ILimitMarket} from "../../src/interfaces/ILimitMarket.sol";
import {IProtocolManager} from "../../src/interfaces/IProtocolManager.sol";
import {TokenManager} from "../../src/TokenManager.sol";
import {ITokenManager} from "../../src/interfaces/ITokenManager.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract BorrowRequestFactoryUnitTest is Test {
    IProtocolManager protocolManager;
    BorrowRequestFactory public borrowRequestFactory;
    ILimitMarket limitMarket;
    ITokenManager tokenManager;
    function setUp() public {
        address protocolManagerProxy = Upgrades.deployUUPSProxy(
            "ProtocolManager.sol",
            abi.encodeCall(ProtocolManager.initialize, ())
        );
        protocolManager = IProtocolManager(protocolManagerProxy);
        address LimitMarketProxy = Upgrades.deployUUPSProxy(
            "LimitMarket.sol",
            abi.encodeCall(LimitMarket.initialize, address(protocolManager))
        );
        limitMarket = ILimitMarket(LimitMarketProxy);
        address TokenManagerProxy = Upgrades.deployUUPSProxy(
            "TokenManager.sol",
            abi.encodeCall(TokenManager.initialize, address(protocolManager))
        );

        tokenManager = ITokenManager(TokenManagerProxy);
        console2.log("test token manager", address(tokenManager));
        // LimitMarket _limitMarket = new LimitMarket(address(protocolManager));
        // limitMarket = ILimitMarket(address(_limitMarket));
        // protocolManager.setLimitMarketContractAddress(address(limitMarket));
        address BorrowRequestFactoryProxy = Upgrades.deployUUPSProxy(
            "BorrowRequestFactory.sol",
            abi.encodeCall(
                BorrowRequestFactory.initialize,
                address(protocolManager)
            )
        );
        borrowRequestFactory = BorrowRequestFactory(BorrowRequestFactoryProxy);

        console2.log(
            "borrowRequestFactory address",
            address(borrowRequestFactory)
        );
    }

    function testCreateRequest() external {
        address borrower = vm.randomAddress();
        vm.deal(borrower, 1000 ether);
        uint256 amount;
        uint256 loanAmountRequested = 60;
        uint256[] memory collateralAmount = new uint256[](6);
        address[] memory tokens = new address[](6);
        vm.startPrank(borrower);
        for (uint256 i = 0; i < collateralAmount.length; i++) {
            string memory name = "meme";
            collateralAmount[i] = amount + 100;
            ERC20Mock token = new ERC20Mock(
                "name",
                "MEME",
                borrower,
                amount + i + 300
            );
            tokens[i] = address(token);
            amount += 100;
            // Reset the allowance to the exact collateralAmount
            erc20TokenLibrary.IncreaseAllowance(
                tokens[i],
                address(borrowRequestFactory),
                collateralAmount[i]
            );
            console2.log("token", i, tokens[i]);
        }
        // console2.log("token length", tokens.length);

        for (uint256 i = 0; i < tokens.length; i++) {
            tokenManager.requestTokenListing{value: 6 ether}(tokens[i]);
            // tokenManager.approveTokenRequest(i);
        }
        vm.stopPrank();
        // console2.log(
        //     " totalRequestedTokens",
        //     tokenManager.totalRequestedTokens()
        // );
        for (uint256 i = 1; i <= tokenManager.totalRequestedTokens(); i++) {
            // console2.log(" loop", tokenManager.totalRequestedTokens());
            // tokenManager.requestTokenListing{value: 6 ether}(tokens[i]);
            tokenManager.approveTokenRequest(i);
            // console2.log("token", i - 1, tokens[i - 1]);
        }
        vm.startPrank(borrower);
        limitMarket.borrow{value: 100 ether}(
            collateralAmount,
            loanAmountRequested,
            tokens,
            false
        );
        vm.stopPrank();
    }
}
