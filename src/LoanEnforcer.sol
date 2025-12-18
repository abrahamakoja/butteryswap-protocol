// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title Enforcer_v1
 * @author Butteryswap Protocol
 * @notice This contract handles the execution of loan requests.
 * it gets the arrays of both borrow and lend requests and processes them in batches of 10 request at a time.
 * the batch processing ensures loans are executed in chronological order based of their block.timestamp when created.
 * this contract also implements a "priority boost" mechanism that allows users to skip the que and have their loans executed next by paying an extra fee.
 * this fee is shared amongst the protocol and the users within the loan requests that eventually seeds the priority loan.
 * this feature is experimental and may or may not be removed.
 */

// debug
import {Script, console} from "forge-std/Script.sol";

/*//////////////////////////////////////////////////////////////
                                IMPORTS
    //////////////////////////////////////////////////////////////*/

import {LoanConfigLibrary} from "./libraries/LoanConfigLibrary.sol";
// import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
// import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IBorrowRequest} from "./interfaces/IBorrowRequest.sol";
import {ILendRequest} from "./interfaces/ILendRequest.sol";
import {ActiveLoan} from "./ActiveLoan.sol";
import {IActiveLoan} from "./interfaces/IActiveLoan.sol";
import {IProtocolManager} from "./interfaces/IProtocolManager.sol";
import {ILimitMarket} from "./interfaces/ILimitMarket.sol";
import {ILendRequestFactory} from "./interfaces/ILendRequestFactory.sol";
import {IBorrowRequestFactory} from "./interfaces/IBorrowRequestFactory.sol";

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract LoanEnforcer is
    AccessControlUpgradeable,
    ReentrancyGuardTransient,
    UUPSUpgradeable
{
    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/
    error LoanEnforcer__UnAuthorized();
    /*//////////////////////////////////////////////////////////////
                                 STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    IProtocolManager private protocolManager;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyExecutor() {
        if (msg.sender != protocolManager.Executor()) {
            revert LoanEnforcer__UnAuthorized();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _protocolManager) public initializer {
        __AccessControl_init();
        protocolManager = IProtocolManager(_protocolManager);
    }

    function _authorizeUpgrade(
        address
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    // function executeLoanDisbursement() external payable onlyExecutor {
    //     address selectedBorrowRequest;
    //     address selectedLendRequest;
    //     (
    //         uint256 totalLendRequests,
    //         uint256 totalPrioritizedLendRequests
    //     ) = ILendRequestFactory(protocolManager.LendRequestFactory())
    //             .getTotalRequests();

    //     (
    //         uint256 totalBorrowRequests,
    //         uint256 totalPrioritizedBorrowRequest
    //     ) = IBorrowRequestFactory(protocolManager.BorrowRequestFactory())
    //             .getTotalRequests();

    //     uint256 lowestNonPrioritizedRequestsCount = totalBorrowRequests >
    //         totalLendRequests
    //         ? totalBorrowRequests
    //         : totalLendRequests;

    //     uint256 lowestPrioritizedRequestsCount = totalPrioritizedBorrowRequest >
    //         totalPrioritizedLendRequests
    //         ? totalPrioritizedBorrowRequest
    //         : totalPrioritizedLendRequests;

    //     uint256 batchLimit = lowestNonPrioritizedRequestsCount <
    //         protocolManager.BATCH_LIMIT()
    //         ? lowestNonPrioritizedRequestsCount
    //         : protocolManager.BATCH_LIMIT();

    //     uint256 prioritizedRequestsLimit = lowestPrioritizedRequestsCount <
    //         protocolManager.PRIORITIZED_BATCH_LIMIT()
    //         ? lowestNonPrioritizedRequestsCount
    //         : protocolManager.PRIORITIZED_BATCH_LIMIT();

    //     if (totalBorrowRequests <= totalLendRequests) {
    //         for (uint256 index = 0; index < batchLimit; index++) {
    //             if (
    //                 totalPrioritizedBorrowRequest >
    //                 protocolManager.INDEX_PRECISION() &&
    //                 totalPrioritizedLendRequests >
    //                 protocolManager.INDEX_PRECISION()
    //             ) {
    //                 for (
    //                     uint256 num = 0;
    //                     num < prioritizedRequestsLimit;
    //                     num++
    //                 ) {
    //                     selectedLendRequest = ILendRequestFactory(
    //                         protocolManager.LendRequestFactory()
    //                     ).getPrioritizedRequestViaIndex(num);

    //                     selectedBorrowRequest = IBorrowRequestFactory(
    //                         protocolManager.BorrowRequestFactory()
    //                     ).getPrioritizedRequestViaIndex(num);
    //                 }
    //             } else {
    //                 selectedLendRequest = ILendRequestFactory(
    //                     protocolManager.LendRequestFactory()
    //                 ).getNonPrioritizedRequestViaIndex(index);

    //                 selectedBorrowRequest = IBorrowRequestFactory(
    //                     protocolManager.BorrowRequestFactory()
    //                 ).getNonPrioritizedRequestViaIndex(index);
    //             }

    //             (
    //                 address[] memory tokens,
    //                 uint256[] memory collateralAmount,
    //                 uint256 loanAmountRequested,
    //                 address borrower,
    //                 uint8 borrowRequestState,

    //             ) = IBorrowRequest(selectedBorrowRequest).getRequestDetails();

    //             (address lender, uint8 lendRequestState, ) = ILendRequest(
    //                 selectedLendRequest
    //             ).getRequestDetails();

    //             if (
    //                 borrowRequestState !=
    //                 uint8(LoanConfigLibrary.RequestState.OPEN) &&
    //                 lendRequestState !=
    //                 uint8(LoanConfigLibrary.RequestState.OPEN)
    //             ) revert();

    //             uint256 availableLiquidity = selectedLendRequest.balance;

    //             uint256 loanOffered = loanAmountRequested <= availableLiquidity
    //                 ? loanAmountRequested
    //                 : availableLiquidity;

    //             ActiveLoan activeLoan = new ActiveLoan(
    //                 borrower,
    //                 lender,
    //                 address(protocolManager),
    //                 collateralAmount,
    //                 tokens,
    //                 loanAmountRequested,
    //                 loanOffered,
    //                 block.timestamp
    //             );

    //             IBorrowRequest(selectedBorrowRequest).acceptLoan(
    //                 address(activeLoan)
    //             );

    //             ILendRequest(selectedLendRequest).offerLoan(
    //                 address(borrower),
    //                 loanOffered
    //             );
    //         }
    //     }

    //     return;
    // }
}
