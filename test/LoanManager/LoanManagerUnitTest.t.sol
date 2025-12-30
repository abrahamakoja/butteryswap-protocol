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
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract LoanManagerUnitTest is Test {
    address borrower;
    IProtocolManager iProtocolManager;
    ILimitMarket iLimitMarket;
    ITokenManager iTokenManager;
    ILoanManager iLoanManager;
    IBackery iBackery;

    address deployer;
    function setUp() public {
        borrower = vm.randomAddress();
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
        iBackery = IBackery(BackeryProxy);
    }

    function testCreateRequest() external {}

    function testPrioritizeBorrowRequest() external {
        vm.deal(borrower, 10 ether);
        uint256 amountToBorrow = 2 ether;
        uint256 tokenListingFee = 1 ether;
        uint256 priorityFee = 1 ether;
        uint256 originationFee = 1 ether;
        uint256 num = 3;
        uint256 amount = 100;
        uint256 requestID;
        address[] memory tokens = new address[](num);
        uint256[] memory collateralAmount = new uint256[](num);
        for (uint256 i = 0; i < collateralAmount.length; i++) {
            collateralAmount[i] = amount;
            amount += amount;
        }
        tokens = _addTokens(tokenListingFee, num, borrower, collateralAmount);
        vm.startPrank(borrower);
        _increaseTokenAllowance(tokens, collateralAmount);
        requestID = _borrow(
            originationFee,
            tokens,
            collateralAmount,
            amountToBorrow,
            false
        );

        // prioritize loan
        iLimitMarket.prioritizeBorrowRequest{value: priorityFee}(requestID);
        // assert
        assertTrue(iLoanManager.isRequestPrioritized(requestID));
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _getBorrowRequestDetails(
        uint256 requestID
    )
        internal
        returns (
            address _borrower,
            uint256 amountToBorrow,
            bool priority,
            uint256 timeCreated,
            uint256 interestRate,
            uint256 dueDate,
            uint256 BreadBalance,
            uint256 _requestID,
            address[] memory _tokens,
            uint256[] memory amountDeposited,
            uint256[] memory tokenvalue,
            uint8 _state
        )
    {
        (
            _borrower,
            amountToBorrow,
            priority,
            timeCreated,
            interestRate,
            dueDate,
            BreadBalance,
            _requestID,
            _tokens,
            amountDeposited,
            tokenvalue,
            _state
        ) = iLoanManager.getBorrowRequestDetails(requestID);
    }

    function _borrow(
        uint256 fee,
        address[] memory tokens,
        uint256[] memory collateralAmount,
        uint256 amountToBorrow,
        bool priority
    ) internal returns (uint256 requestID) {
        iLimitMarket.borrow{value: fee}(
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
        uint256 fee,
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
            iTokenManager.requestTokenListing{value: fee}(tokens[i]);
        }
        vm.stopPrank();

        // approve
        vm.startPrank(deployer);
        for (uint256 i = 1; i <= iTokenManager.totalRequestedTokens(); i++) {
            iTokenManager.approveTokenRequest(i);
        }
        vm.stopPrank();
    }
}
