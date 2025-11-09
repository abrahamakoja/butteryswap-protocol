// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {ProtocolManager} from "../../src/ProtocolManager.sol";
import {BorrowRequestFactory} from "../../src/BorrowRequestFactory.sol";
import {LimitMarket} from "../../src/LimitMarket.sol";
import {ILimitMarket} from "../../src/interfaces/ILimitMarket.sol";
import {TokenManager} from "../../src/TokenManager.sol";
import {ITokenManager} from "../../src/interfaces/ITokenManager.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract BorrowRequestFactoryUnitTest is Test {
    ProtocolManager protocolManager;
    BorrowRequestFactory borrowRequestFactory;
    ILimitMarket limitMarket;
    function setUp() public {
        protocolManager = new ProtocolManager();
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
        address LimitMarketProxy = Upgrades.deployUUPSProxy(
            "LimitMarket.sol",
            abi.encodeCall(LimitMarket.initialize, address(protocolManager))
        );
        limitMarket = ILimitMarket(LimitMarketProxy);
        BorrowRequestFactory _borrowRequestFactory = BorrowRequestFactory(
            BorrowRequestFactoryProxy
        );
        borrowRequestFactory = _borrowRequestFactory;
    }

    function testCreateRequest() external {
        //  uint256[] calldata collateralAmount,
        // uint256 loanAmountRequested,
        // address[] calldata tokens,
        // address borrower,
        // protocolManager.setLimitMarketContractAddress(address(limitMarket));
        console2.log("test limit", address(limitMarket));
        console2.log(
            "test function protocolmanager limit",
            protocolManager.LIMIT_MARKET_CONTRACT_ADDRESS()
        );
        protocolManager.updateBorrowRequestFactoryContract(
            address(borrowRequestFactory)
        );
        address borrower = vm.randomAddress();
        uint256 amount;
        uint256 loanAmountRequested = 6000;
        uint256[] memory collateralAmount = new uint256[](6);
        address[] memory tokens = new address[](6);
        for (uint i = 0; i < collateralAmount.length; i++) {
            collateralAmount[i] = amount + 100;
            tokens[i] = vm.randomAddress();
            amount += 100;
        }
        limitMarket.borrow(
            collateralAmount,
            loanAmountRequested,
            tokens,
            false
        );
    }
}
