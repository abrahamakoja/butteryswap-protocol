// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title LimitMarket
 * @author ButterySwap Protocol
 * @notice
 */

// debug
import {Script, console2} from "forge-std/Script.sol";

/*//////////////////////////////////////////////////////////////
                                IMPORTS
    //////////////////////////////////////////////////////////////*/

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IProtocolManager} from "./interfaces/IProtocolManager.sol";
// // import {IBorrowRequestFactory} from "./interfaces/IBorrowRequestFactory.sol";
// import {ITokenManager} from "./interfaces/ITokenManager.sol";
import {ILoanManager} from "./interfaces/ILoanManager.sol";
// import {ILendRequestFactory} from "./interfaces/ILendRequestFactory.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract LimitMarket is
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardTransient
{
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error LimitMarket_UnauthorizedAccess(address caller);
    error LimitMarket_BorrowRequestFailed();
    // new
    error LimitMarket__rangeDataMisMatch();
    error LimitMarket__InvalidTokenCount(uint256 tokenCount);
    error LimitMarket__unSupportedToken(address token);
    error LimitMarket__NoCollateralSent(uint256 collateralAmount);
    error LimitMarket_EnforcerNotInitialized();
    error LimitMarket_NoAmountSent(uint256 balance, uint256 amountSent);
    error LimitMarket_InvalidAmount(uint256 balance, uint256 amountSent);
    error LimitMarket_InsufficientBalance(uint256 balance, uint256 collateral);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    IProtocolManager private ProtocolManager; // @audit change case

    ILoanManager LoanManager;

    bytes32 public LIMIT_MARKET_ADMIN;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event TokensDeposited(
        address indexed user,
        address[] tokenAddress,
        uint256 amount
    );

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _protocolManager) public initializer {
        __AccessControl_init();

        LIMIT_MARKET_ADMIN = keccak256("LIMIT_MARKET_ADMIN");
        address deployer = IProtocolManager(_protocolManager).deployer();

        _grantRole(DEFAULT_ADMIN_ROLE, deployer);
        _grantRole(LIMIT_MARKET_ADMIN, deployer);
        ProtocolManager = IProtocolManager(_protocolManager);

        LoanManager = ILoanManager(ProtocolManager.LoanManager());
        ProtocolManager.setLimitMarketContractAddress(address(this));
    }

    function _authorizeUpgrade(
        address
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL BORROW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal function to create a new BorrowRequest instance
    /// @param collateralAmount The amount of collateral to be locked
    /// @param tokens The list of tokens to be used as collateral
    function borrow(
        address[] calldata tokens,
        uint256[] calldata collateralAmount,
        uint256 amountToBorrow,
        bool priority
    ) external payable nonReentrant returns (uint256 borrowRequestID) {
        // checks
        require(
            (collateralAmount.length == tokens.length),
            LimitMarket__rangeDataMisMatch()
        ); //@audit rename errors

        if (
            tokens.length == 0 ||
            tokens.length > ProtocolManager.MAX_ASSET_LIMIT()
        ) revert LimitMarket__InvalidTokenCount(tokens.length);

        address borrower = msg.sender;

        require(msg.value >= 1 ether); // @audit use fee and add revert error for failure

        if (
            address(LoanManager) == address(0) ||
            address(ProtocolManager.LoanManager()) != address(LoanManager)
        ) {
            LoanManager = ILoanManager(address(ProtocolManager.LoanManager()));
            require(address(LoanManager) != address(0), "LoanManager not set");
        }

        borrowRequestID = LoanManager.createBorrowRequest{value: msg.value}({
            tokens: tokens,
            collateralAmount: collateralAmount,
            amountToBorrow: amountToBorrow,
            borrower: borrower,
            priority: priority
        });
    }

    // function addLiquidityToBorrowRequest(
    //     address borrowRequest,
    //     address[] calldata tokens,
    //     uint256[] calldata collateralAmounts,
    //     uint256 _loanAmountRequested
    // ) external payable nonReentrant {
    //     IBorrowRequestFactory(protocolManager.BorrowRequestFactory())
    //         .addLiquidity(
    //             msg.sender,
    //             borrowRequest,
    //             tokens,
    //             collateralAmounts,
    //             _loanAmountRequested
    //         );
    // }

    // function prioritizeBorrowRequest(
    //     address borrowRequest
    // ) external payable nonReentrant {
    //     IBorrowRequestFactory(protocolManager.BorrowRequestFactory())
    //         .prioritizeLoanRequest(msg.sender, borrowRequest);
    // }

    // function cancelBorrowRequest(
    //     address borrowRequest
    // ) external payable nonReentrant {
    //     IBorrowRequestFactory(protocolManager.BorrowRequestFactory())
    //         .cancelRequest(msg.sender, borrowRequest);
    // }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL LEND FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // function Lend(bool _priority) external payable nonReentrant {
    //     ILendRequestFactory(protocolManager.LendRequestFactory()).createRequest(
    //         msg.sender,
    //         _priority
    //     );
    // }

    // function prioritizeLendRequest(
    //     address lendRequest
    // ) external payable nonReentrant {
    //     ILendRequestFactory(protocolManager.LendRequestFactory())
    //         .prioritizeLoanRequest(msg.sender, lendRequest);
    // }
    // function addLiquidityToLendRequest(
    //     address lendRequest
    // ) external payable nonReentrant {
    //     ILendRequestFactory(protocolManager.LendRequestFactory()).addLiquidity(
    //         msg.sender,
    //         lendRequest
    //     );
    // }
    // function cancelLendRequest(
    //     address lendRequest
    // ) external payable nonReentrant {
    //     ILendRequestFactory(protocolManager.LendRequestFactory()).cancelRequest(
    //         msg.sender,
    //         lendRequest
    //     );
    // }

    // gap
    uint256[60] private __gap;

    ////////////////////////
    /// Public Functions ///
    ////////////////////////

    ////////////////////////
    /// Internal Functions ///
    ////////////////////////

    ////////////////////////
    /// Private Functions ///
    ////////////////////////

    ////////////////////////////////////////////////
    /// External & Public View & Pure Functions ///
    //////////////////////////////////////////////

    // **** borrow requests functions ****//
    /// move all getters to individual interfaces or limit market interface
    // function getBorrowersPositionOnQue(
    //     address borrowRequest
    // ) external view returns (uint256 position) {
    //     return
    //         BorrowRequestFactory.getBorrowRequestPositionOnActiveRequestQue(
    //             borrowRequest
    //         );
    // }

    // returns specific number of requests using a start index and a number of requested contracts
    // function getActiveBorrowRequestViaLimit(
    //     uint256 _startIndex,
    //     uint256 _numberOfResponse,
    //     uint256 _batchLimit
    // ) external view returns (address[] memory borrowRequests) {
    //     return
    //         BorrowRequestFactory.getBatchedActiveBorrowRequestContractAddresses(
    //             _startIndex,
    //             _numberOfResponse,
    //             _batchLimit
    //         );
    // }

    // @dev returns the total active borrow requests count.
    // function getTotalActiveBorrowRequestContractCount()
    //     external
    //     view
    //     returns (uint256 numberOfContracts)
    // {
    //     return BorrowRequestFactory.getTotalActiveBorrowRequestContractCount();
    // }

    // @dev returns the total active borrow requests prioritized addresses.
    // function getPrioritizedBorrowRequestAddress(
    //     uint256 batchLimit,
    //     uint256 numOfResponse
    // ) external view returns (address[] memory prioritizedLoans) {
    //     return
    //         BorrowRequestFactory.getTotalActivePrioritizedBorrowRequests(
    //             batchLimit,
    //             numOfResponse
    //         );
    // }

    // **** lend requests functions ****//

    // function getLendersPositionOnQue(
    //     address lendRequest
    // ) external view returns (uint256 position) {
    //     return
    //         LendRequestFactory.getLendRequestPositionOnActiveRequestQue(
    //             lendRequest
    //         );
    // }

    // function getPrioritizedLendRequestAddress(
    //     uint256 batchLimit,
    //     uint256 numOfResponse
    // ) external view returns (address[] memory prioritizedLoans) {
    //     return
    //         LendRequestFactory.getTotalActivePrioritizedLendRequests(
    //             batchLimit,
    //             numOfResponse
    //         );
    // }

    // @dev returns the total active lend requests count.
    // function getTotalActiveLendRequestContractCount()
    //     external
    //     view
    //     returns (uint256 count)
    // {
    //     return LendRequestFactory.getTotalActiveLendRequestContractCount();
    // }

    // returns specific number of requests using a start index and a number of requested contracts
    // function getActiveLendRequestViaLimit(
    //     uint256 _startIndex,
    //     uint256 _numberOfResponse,
    //     uint256 _batchLimit
    // ) external view returns (address[] memory lendRequests) {
    //     return
    //         LendRequestFactory.getBatchedActiveLendRequestAddresses(
    //             _startIndex,
    //             _numberOfResponse,
    //             _batchLimit
    //         );
    // }
}
