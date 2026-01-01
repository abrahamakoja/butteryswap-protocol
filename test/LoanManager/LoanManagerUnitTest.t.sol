// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {erc20TokenLibrary} from "../../src/libraries/erc20TokenLibrary.sol";
import {ProtocolManager} from "../../src/ProtocolManager.sol";
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
import {IProtocolManager} from "../../src/interfaces/IProtocolManager.sol";
import {Backer} from "../../src/Backer.sol";
import {IBacker} from "../../src/interfaces/IBacker.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract LoanManagerUnitTest is Test {
    address borrower;
    address lender;
    IProtocolManager iProtocolManager;
    ILimitMarket iLimitMarket;
    ITokenManager iTokenManager;
    ILoanManager iLoanManager;
    IBackery iBackery;

    address deployer;

    struct TestVars {
        uint256 x;
        uint256 amountToBorrow;
        uint256 listingFee;
        uint256 topUpFee;
        uint256 originationFee;
        uint256 num;
        uint256 amount;
        uint256 requestID;
        uint256 newAmount;
        uint256 newAmountToBorrow;
        bool priority;
        address[] tokens;
        address[] token2;
        address[] token1;
        uint256[] collateralAmount;
        uint256[] collateralAmount2;
        uint256[] collateralAmount1;
        uint256[] newCollateralAmount;
    }

    function setUp() public {
        borrower = vm.randomAddress();
        lender = vm.randomAddress();
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

        // TokenManager
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
        iBackery = IBackery(BackeryProxy);
    }

    function testCreateRequest() external {}

    function testPrioritizeBorrowRequest() external {}

    function testIncreaseCollaterallAmount() external {
        //  @audit known issue with tokenmanager accounting
        // @audit test incomplete fix tokenManager
        vm.deal(borrower, 100 ether);

        TestVars memory testVars;
        testVars.num = 6;
        testVars.amount = 6e18;
        testVars.originationFee = 1 ether;
        testVars.listingFee = 1 ether;
        testVars.amountToBorrow = 6 ether;
        testVars.priority = false;
        address[] memory _tokens;
        uint256[] memory collateralAmount2;

        (testVars.requestID, _tokens, testVars.collateralAmount) = _quickSetup(
            testVars.listingFee,
            testVars.num,
            borrower,
            testVars.amount,
            testVars.amountToBorrow,
            testVars.priority,
            testVars.originationFee
        );

        console2.log(" testVars.tokens", testVars.tokens.length);
        console2.log(" _tokens", _tokens.length);
        iLoanManager.getBorrowRequestDetails(testVars.requestID);

        testVars.tokens = new address[](3);
        collateralAmount2 = _collateralAmount(10e18, 3);
        testVars.tokens = _addTokens(
            testVars.listingFee,
            3,
            borrower,
            collateralAmount2
        );
        _increaseTokenAllowance(_tokens, collateralAmount2);

        iLimitMarket.increaseCollaterallAmount{value: 2 ether}(
            testVars.requestID,
            _tokens,
            collateralAmount2,
            testVars.amountToBorrow * 2
        );

        iLoanManager.getBorrowRequestDetails(testVars.requestID);
    }

    function testCancelBorrowRequest() external {
        vm.deal(borrower, 100 ether);

        TestVars memory testVars;
        address[] memory _tokens;
        testVars.num = 6;
        testVars.amount = 6e18;
        testVars.originationFee = 1 ether;
        testVars.listingFee = 1 ether;
        testVars.amountToBorrow = 6 ether;
        testVars.priority = false;

        (testVars.requestID, _tokens, testVars.collateralAmount) = _quickSetup(
            testVars.listingFee,
            testVars.num,
            borrower,
            testVars.amount,
            testVars.amountToBorrow,
            testVars.priority,
            testVars.originationFee
        );
        console2.log("what is ID", testVars.requestID);
        iLoanManager.getBorrowRequestDetails(testVars.requestID);
        iLoanManager.getBorrowRequestTokenDetails(testVars.requestID);
        iLoanManager.getBorrowerRequestTokenBalance(testVars.requestID);
        // return;
        // iBackery.getTotalSupply(2);
        // uint256 count2 = iLoanManager.getTotalBorrowRequestCount();
        // console2.log("what is ", requestID);
        iLimitMarket.cancelBorrowRequest{value: 1 ether}(testVars.requestID);
        iLoanManager.getBorrowerRequestTokenBalance(testVars.requestID);
        uint256 count = iLoanManager.getTotalBorrowRequestCount();
        iBackery.getBalance(borrower, testVars.requestID);
        iBackery.getTotalSupply(1);
        iBackery.getTotalSupply(2);
    }

    function testLend() external {
        vm.startPrank(lender);
        vm.deal(lender, 20 ether);

        console2.log("test contract before", address(iLoanManager).balance);
        iBackery.approve(address(deployer), 1, UINT256_MAX);
        uint256 requestID = iLimitMarket.lend{value: 6 ether}();
        console2.log("test contract after", address(iLoanManager).balance);
        iLoanManager.getLendRequestDetails(requestID);

        console2.log("start here");
        iBackery.getTotalSupply(1);
        iBackery.getTotalSupply(2);
        iBackery.getBalance(borrower, requestID);
        iBackery.getBalance(lender, requestID);
        vm.stopPrank();
        vm.startPrank(deployer);

        iBackery.transferFrom(lender, borrower, 1, 1);
        iBackery.getBalance(borrower, requestID);
        iBackery.getBalance(lender, requestID);
        iBackery.getTotalSupply(1);
        iBackery.getTotalSupply(2);
    }

    function testCancelLendRequest() external {
        vm.startPrank(lender);
        vm.deal(lender, 20 ether);

        console2.log("test contract before", address(iLoanManager).balance);
        uint256 requestID = iLimitMarket.lend{value: 6 ether}();
        console2.log("test contract after", address(iLoanManager).balance);
        iLoanManager.getLendRequestDetails(requestID);
        iLimitMarket.cancelLendRequest{value: 3 ether}(requestID);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _quickSetup(
        uint256 listingFee,
        uint256 num,
        address user,
        uint256 amount,
        uint256 amountToBorrow,
        bool priority,
        uint256 originationFee
    )
        internal
        returns (
            uint256 requestID,
            address[] memory _tokens,
            uint256[] memory collateralAmount
        )
    {
        collateralAmount = _collateralAmount(amount, num);
        _tokens = _addTokens(listingFee, num, user, collateralAmount);
        vm.startPrank(user);
        _increaseTokenAllowance(_tokens, collateralAmount);
        requestID = _borrow(
            originationFee,
            _tokens,
            collateralAmount,
            amountToBorrow,
            priority
        );
        return (requestID, _tokens, collateralAmount);
        vm.stopPrank();
    }

    function _collateralAmount(
        uint256 amount,
        uint256 num
    ) internal returns (uint256[] memory _collateralAmount) {
        _collateralAmount = new uint256[](num);
        for (uint i = 0; i < num; i++) {
            _collateralAmount[i] = amount;
            amount += amount;
        }
    }

    function _borrow(
        uint256 originationFee,
        address[] memory tokens,
        uint256[] memory collateralAmount,
        uint256 amountToBorrow,
        bool priority
    ) internal returns (uint256 requestID) {
        requestID = iLimitMarket.borrow{value: originationFee}(
            tokens,
            collateralAmount,
            amountToBorrow,
            false
        );
    }

    function _increaseTokenAllowance(
        address[] memory tokens,
        uint256[] memory collateralAmount
    ) internal {
        for (uint256 i = 0; i < tokens.length; i++) {
            erc20TokenLibrary.IncreaseAllowance(
                tokens[i],
                address(iLoanManager),
                collateralAmount[i]
            );
        }
    }

    function _addTokens(
        uint256 listingFee,
        uint256 num,
        address user,
        uint256[] memory collateralAmount
    ) private returns (address[] memory tokens) {
        vm.startPrank(user);

        tokens = new address[](num);
        for (uint256 i = 0; i < num; i++) {
            string memory name = "meme coin";

            ERC20Mock token = new ERC20Mock(
                name,
                "MEME",
                user,
                collateralAmount[i]
            );
            tokens[i] = address(token);
        }
        // request
        for (uint256 i = 0; i < tokens.length; i++) {
            iTokenManager.requestTokenListing{value: listingFee}(tokens[i]);
        }
        vm.stopPrank();

        // approve
        vm.startPrank(deployer);
        for (uint256 i = 0; i <= iTokenManager.totalRequestedTokens(); i++) {
            iTokenManager.approveTokenRequest(i);
        }
        vm.stopPrank();
    }
}
