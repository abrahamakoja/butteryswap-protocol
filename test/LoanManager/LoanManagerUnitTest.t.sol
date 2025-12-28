// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
// import {BorrowRequest} from "../../src/BorrowRequest.sol";
import {erc20TokenLibrary} from "../../src/libraries/erc20TokenLibrary.sol";
import {ProtocolManager} from "../../src/ProtocolManager.sol";
// import {BorrowRequestFactory} from "../../src/BorrowRequestFactory.sol";
import {LimitMarket} from "../../src/LimitMarket.sol";
import {LoanManager} from "../../src/LoanManager.sol";
import {ILimitMarket} from "../../src/interfaces/ILimitMarket.sol";
import {ILoanManager} from "../../src/interfaces/ILoanManager.sol";
import {IProtocolManager} from "../../src/interfaces/IProtocolManager.sol";
import {TokenManager} from "../../src/TokenManager.sol";
import {ITokenManager} from "../../src/interfaces/ITokenManager.sol";
import {IProtocolManager} from "../../src/interfaces/IProtocolManager.sol";
import {Backery} from "../../src/Backery.sol";
import {IBackery} from "../../src/interfaces/IBackery.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
// import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract LoanManagerUnitTest is Test {
    IProtocolManager iProtocolManager;
    ILimitMarket iLimitMarket;
    ITokenManager iTokenManager;
    ILoanManager iLoanManager;
    IBackery iBackery;
    // UpgradeableBeacon beacon;
    address deployer;
    function setUp() public {
        // protocolManager
        address protocolManagerProxy = Upgrades.deployUUPSProxy(
            "ProtocolManager.sol",
            abi.encodeCall(ProtocolManager.initialize, ())
        );
        iProtocolManager = IProtocolManager(protocolManagerProxy);
        deployer = IProtocolManager(protocolManagerProxy).deployer();

        // limit Market
        address LimitMarketProxy = Upgrades.deployUUPSProxy(
            "LimitMarket.sol",
            abi.encodeCall(
                LimitMarket.initialize,
                address(protocolManagerProxy)
            )
        );

        iLimitMarket = ILimitMarket(LimitMarketProxy);

        // iTokenManager
        address TokenManagerProxy = Upgrades.deployUUPSProxy(
            "TokenManager.sol",
            abi.encodeCall(
                TokenManager.initialize,
                address(protocolManagerProxy)
            )
        );
        iTokenManager = ITokenManager(TokenManagerProxy);

        // loanManager
        address LoanManagerProxy = Upgrades.deployUUPSProxy(
            "LoanManager.sol",
            abi.encodeCall(
                LoanManager.initialize,
                address(protocolManagerProxy)
            )
        );
        iLoanManager = ILoanManager(LoanManagerProxy);
        // Backery
        address BackeryProxy = Upgrades.deployUUPSProxy(
            "Backery.sol",
            abi.encodeCall(Backery.initialize, address(protocolManagerProxy))
        );
        iBackery = IBackery(LoanManagerProxy);

        // console2.log("limit contract", address(iLimitMarket));
    }

    function testCreateRequest() external {
        // return ();
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
                name,
                "MEME",
                borrower,
                UINT256_MAX
            );
            tokens[i] = address(token);
            amount += 100;
            // Reset the allowance to the exact collateralAmount
            erc20TokenLibrary.IncreaseAllowance(
                tokens[i],
                address(iLoanManager),
                collateralAmount[i]
            );
            console2.log("token", i, tokens[i]);
        }
        // console2.log("token length", tokens.length);

        for (uint256 i = 0; i < tokens.length; i++) {
            iTokenManager.requestTokenListing{value: 6 ether}(tokens[i]);
            // iTokenManager.approveTokenRequest(i);
        }
        vm.stopPrank();

        for (uint256 i = 1; i <= iTokenManager.totalRequestedTokens(); i++) {
            iTokenManager.approveTokenRequest(i);
        }

        vm.startPrank(borrower);
        for (uint256 i = 0; i < tokens.length; i++) {
            // Reset the allowance to the exact collateralAmount
            erc20TokenLibrary.IncreaseAllowance(
                tokens[i],
                address(iLoanManager),
                2000
            );
        }
        console2.log("limit contract", address(iLimitMarket));
        uint8 borrowRequestId = iLimitMarket.borrow{value: 200 ether}(
            tokens,
            collateralAmount,
            loanAmountRequested,
            false
        );

        vm.stopPrank();
    }
}
