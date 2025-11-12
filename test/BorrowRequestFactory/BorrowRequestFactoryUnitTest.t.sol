// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {BorrowRequest} from "../../src/BorrowRequest.sol";
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
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract BorrowRequestFactoryUnitTest is Test {
    IProtocolManager protocolManager;
    BorrowRequestFactory borrowRequestFactory;
    ILimitMarket limitMarket;
    ITokenManager tokenManager;
    UpgradeableBeacon beacon;
    address deployer;
    function setUp() public {
        // protocolManager
        address protocolManagerProxy = Upgrades.deployUUPSProxy(
            "ProtocolManager.sol",
            abi.encodeCall(ProtocolManager.initialize, ())
        );
        protocolManager = IProtocolManager(protocolManagerProxy);
        address LimitMarketProxy = Upgrades.deployUUPSProxy(
            "LimitMarket.sol",
            abi.encodeCall(LimitMarket.initialize, address(protocolManager))
        );
        deployer = protocolManager.deployer();

        // limitMarket
        limitMarket = ILimitMarket(LimitMarketProxy);

        // tokenManager
        address TokenManagerProxy = Upgrades.deployUUPSProxy(
            "TokenManager.sol",
            abi.encodeCall(TokenManager.initialize, address(protocolManager))
        );
        tokenManager = ITokenManager(TokenManagerProxy);
        console2.log("test token manager", address(tokenManager));

        // borrow request implementation
        BorrowRequest implementation = new BorrowRequest();
        protocolManager.setBorrowRequestImplementation(address(implementation));
        beacon = new UpgradeableBeacon(address(implementation), deployer);

        // borrow request factory
        address BorrowRequestFactoryProxy = Upgrades.deployUUPSProxy(
            "BorrowRequestFactory.sol",
            abi.encodeCall(
                BorrowRequestFactory.initialize,
                (address(protocolManager), address(beacon))
            )
        );
        borrowRequestFactory = BorrowRequestFactory(BorrowRequestFactoryProxy);
        beacon.transferOwnership(address(borrowRequestFactory));

        console2.log(
            "borrowRequestFactory address",
            address(borrowRequestFactory)
        );
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
                "name",
                "MEME",
                borrower,
                UINT256_MAX
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
        // vm.startPrank(msg.sender);
        for (uint256 i = 1; i <= tokenManager.totalRequestedTokens(); i++) {
            // console2.log(" loop", tokenManager.totalRequestedTokens());
            // tokenManager.requestTokenListing{value: 6 ether}(tokens[i]);
            tokenManager.approveTokenRequest(i);
            // console2.log("token", i - 1, tokens[i - 1]);
        }
        // vm.stopPrank();
        vm.startPrank(borrower);
        address borrowRequest = limitMarket.borrow{value: 100 ether}(
            collateralAmount,
            loanAmountRequested,
            tokens,
            false
        );
        BorrowRequest(borrowRequest).getRequestDetails();
        console2.log("beacon owner", address(beacon.owner()));
        console2.log("deployer", address(deployer));
        vm.stopPrank();

        vm.startPrank(deployer);
        BorrowRequestV2 borrowRequestV2 = new BorrowRequestV2();
        UpgradeableBeacon beacon2 = new UpgradeableBeacon(
            address(borrowRequestV2),
            deployer
        );
        // address newImplementation = address(UpgradeableBeacon(borrowRequestV2));
        // protocolManager.setBorrowRequestImplementation(
        //     address(borrowRequestV2)
        // );
        borrowRequestFactory.upgradeImplementation(address(beacon2));
        vm.stopPrank();

        vm.startPrank(borrower);
        for (uint256 i = 0; i < tokens.length; i++) {
            // Reset the allowance to the exact collateralAmount
            erc20TokenLibrary.IncreaseAllowance(
                tokens[i],
                address(borrowRequestFactory),
                2000
            );
        }
        address borrowRequest2 = limitMarket.borrow{value: 200 ether}(
            collateralAmount,
            loanAmountRequested,
            tokens,
            false
        );
        // BorrowRequestV2(borrowRequest2).getRequestDetails();
        vm.stopPrank();
    }
}

pragma solidity ^0.8.28;

/**
 * @title BorrowRequest v1
 * @author ButterySwap
 * @notice This contract handles the management of a borrow requests before it is processed by the loanEnforcer contract or cancelled by the user.
 * users can top up their loans by adding liquidity to the borrow request but cannot remove the added liquidity unless they decide to cancel the request entirely,
 * by cancelling the request, the user's liquidity is returned to their wallet after a cancellation fee is removed.
 */

// debug
import {Script, console} from "forge-std/Script.sol";

/*//////////////////////////////////////////////////////////////
                                 IMPORT
    //////////////////////////////////////////////////////////////*/

import {LoanConfigLibrary} from "../../src/libraries/LoanConfigLibrary.sol";
import {IProtocolManager} from "../../src/interfaces/IProtocolManager.sol";

contract BorrowRequestV2 {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error BorrowRequest__UnauthorizedAccess();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    // @audit create a way to change these if needed in the main contract and add more variables after upgrade include --gap
    IProtocolManager private protocolManager;

    bool private initialized;

    using LoanConfigLibrary for LoanConfigLibrary.BorrowRequest;
    LoanConfigLibrary.BorrowRequest private s_borrowRequest;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyEnforcer() {
        if (msg.sender != address(protocolManager.Enforcer()))
            revert BorrowRequest__UnauthorizedAccess();
        _;
    }

    modifier onlyFactory() {
        if (msg.sender != protocolManager.BorrowRequestFactory())
            revert BorrowRequest__UnauthorizedAccess();
        _;
    }

    function initialize(
        address borrower,
        uint256[] memory collateralAmount,
        uint256 loanAmountRequested,
        address[] memory token,
        uint256 _timeCreated,
        address _protocolManager
    ) external payable {
        require(!initialized, "Already initialized");
        s_borrowRequest = LoanConfigLibrary.createBorrowRequest(
            borrower,
            collateralAmount,
            loanAmountRequested,
            token,
            _timeCreated
        );
        protocolManager = IProtocolManager(_protocolManager);
        initialized = true;
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function updateRequest(
        address token,
        uint256 index,
        uint256 collateralAmount,
        uint256 _loanAmountRequested
    ) external onlyFactory {
        s_borrowRequest.updateBorrowRequest(
            token,
            index,
            collateralAmount,
            _loanAmountRequested
        );
    }

    function updateRequestState(uint8 state) external onlyFactory {
        s_borrowRequest.updateBorrowRequestState(state);
    }

    // function resetRequestDetails() internal {
    //     s_borrowRequest.resetBorrowRequestDetails();
    // }

    function acceptLoan(address activeLoan) external onlyEnforcer {
        // emit LoanAccepted(vault);
        // s_borrowRequest.acceptLoan( address(vault));
        // request.state = RequestState.SETTLED;
        // for (uint256 index = 0; index < request.tokens.length; index++) {
        //     erc20TokenLibrary.transferTokens(
        //         address(request.tokens[index]),
        //         address(activeLoanAddress),
        //         request.collateralAmountMinusFee
        //     );
        // }
        // erc20TokenLibrary.transferTokens(address(request.memeCoin), address(multisigAddress), 10);
    }

    // Function to get the borrow request details
    function getRequestDetails()
        external
        view
        returns (address[] memory tokens, address borrower)
    {
        (address[] memory _tokens, , , address _borrower, , ) = s_borrowRequest
            .getBorrowRequestDetails();

        return (_tokens, _borrower);
    }
}
