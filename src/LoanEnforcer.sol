// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IBorrowRequest} from "./interfaces/IBorrowRequest.sol";
import {ILendRequest} from "./interfaces/ILendRequest.sol";
import {ActiveLoan} from "./ActiveLoan.sol";
import {IActiveLoan} from "./interfaces/IActiveLoan.sol";
import {IProtocolManager} from "./interfaces/IProtocolManager.sol";
import {ILimitMarket} from "./interfaces/ILimitMarket.sol";
import {ILendRequestFactory} from "./interfaces/ILendRequestFactory.sol";
import {IBorrowRequestFactory} from "./interfaces/IBorrowRequestFactory.sol";

contract LoanEnforcer is Script, ReentrancyGuard, Ownable {
    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/
    error LoanEnforcer__UnAuthorized();
    /*//////////////////////////////////////////////////////////////
                                 STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    IProtocolManager private immutable protocolManager;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyExecutor() {
        if (msg.sender != protocolManager.Executor()) {
            revert LoanEnforcer__UnAuthorized();
        }
        _;
    }
    constructor(address _protocolManager) Ownable(msg.sender) {
        protocolManager = IProtocolManager(_protocolManager);
    }

    function executeLoanDisbursement() external payable onlyExecutor {
        address selectedBorrowRequest;
        address selectedLendRequest;
        (
            uint256 totalLendRequests,
            uint256 totalPrioritizedLendRequests
        ) = ILendRequestFactory(protocolManager.LendRequestFactory())
                .getTotalRequests();

        (
            uint256 totalBorrowRequests,
            uint256 totalPrioritizedBorrowRequest
        ) = IBorrowRequestFactory(protocolManager.BorrowRequestFactory())
                .getTotalRequests();

        uint256 lowestNonPrioritizedRequestsCount = totalBorrowRequests >
            totalLendRequests
            ? totalBorrowRequests
            : totalLendRequests;

        uint256 lowestPrioritizedRequestsCount = totalPrioritizedBorrowRequest >
            totalPrioritizedLendRequests
            ? totalPrioritizedBorrowRequest
            : totalPrioritizedLendRequests;

        uint256 batchLimit = lowestNonPrioritizedRequestsCount <
            protocolManager.BATCH_LIMIT()
            ? lowestNonPrioritizedRequestsCount
            : protocolManager.BATCH_LIMIT();

        uint256 prioritizedRequestsLimit = lowestPrioritizedRequestsCount <
            protocolManager.PRIORITIZED_BATCH_LIMIT()
            ? lowestNonPrioritizedRequestsCount
            : protocolManager.PRIORITIZED_BATCH_LIMIT();

        if (totalBorrowRequests <= totalLendRequests) {
            for (uint256 index = 0; index < batchLimit; index++) {
                if (
                    totalPrioritizedBorrowRequest >
                    protocolManager.INDEX_PRECISION() &&
                    totalPrioritizedLendRequests >
                    protocolManager.INDEX_PRECISION()
                ) {
                    for (
                        uint256 num = 0;
                        num < prioritizedRequestsLimit;
                        num++
                    ) {
                        selectedLendRequest = ILendRequestFactory(
                            protocolManager.LendRequestFactory()
                        ).getPrioritizedRequestViaIndex(num);

                        selectedBorrowRequest = IBorrowRequestFactory(
                            protocolManager.BorrowRequestFactory()
                        ).getPrioritizedRequestViaIndex(num);
                    }
                } else {
                    selectedLendRequest = ILendRequestFactory(
                        protocolManager.LendRequestFactory()
                    ).getNonPrioritizedRequestViaIndex(index);

                    selectedBorrowRequest = IBorrowRequestFactory(
                        protocolManager.BorrowRequestFactory()
                    ).getNonPrioritizedRequestViaIndex(index);
                }


                (
                    address[] memory tokens,
                    uint256[] memory collateralAmount,
                    uint256 loanAmountRequested,
                    address borrower,
                    LoanConfigLibrary.RequestState borrowRequestState,

                ) = IBorrowRequest(selectedBorrowRequest)
                        .getBorrowRequestDetails();

                (
                    address lender,
                    LoanConfigLibrary.RequestState lendRequestState,

                ) = ILendRequest(selectedLendRequest).getRequestDetails();

                if (
                    borrowRequestState != LoanConfigLibrary.RequestState.OPEN &&
                    lendRequestState != LoanConfigLibrary.RequestState.OPEN
                ) revert();

                uint256 availableLiquidity = selectedLendRequest.balance;

                uint256 loanOffered = loanAmountRequested <= availableLiquidity
                    ? loanAmountRequested
                    : availableLiquidity;

                ActiveLoan activeLoan = new ActiveLoan(
                    borrower,
                    lender,
                    address(protocolManager),
                    collateralAmount,
                    tokens,
                    loanAmountRequested,
                    loanOffered,
                    block.timestamp
                );

                IBorrowRequest(selectedBorrowRequest).acceptLoan(
                    address(activeLoan)
                );

                ILendRequest(selectedLendRequest).offerLoan(
                    address(borrower),
                    loanOffered
                );
            }
        }

        return;
    }
}

// s_settledBorrowRequest[
//     address(_activeBorrowRequestAddress)
// ] = index;
// s_settledLendRequest[
//     address(_activeLendRequestAddress)
// ] = index;
// // update mapping of borrower address to active active loan
// userToActiveLoanContract[address(activeBorrower)].push(
//     address(_activeLoan)
// );
// // update mapping of lender address to active active loan
// userToActiveLoanContract[address(activeLender)].push(
//     address(_activeLoan)
// );
// // update s_activeBorrowRequestAddress
// s_activeBorrowRequestAddress = _activeBorrowRequestAddress;
// // update s_activeLendRequestAddress
// s_activeLendRequestAddress = _activeLendRequestAddress;

// /// *** emits *** ///
// emit loanOfferExecuted(address(_activeLoan));

// /// *** interactions *** ///

/// *** effects *** ///
// s_settledBorrowRequest[address(_activeBorrowRequestAddress)] = index;
// s_settledLendRequest[address(_activeLendRequestAddress)] = index;
// // update mapping of borrower address to active active loan
// userToActiveLoanContract[address(activeBorrower)].push( address(_activeLoan));
// // update mapping of lender address to active active loan
// userToActiveLoanContract[address(activeLender)].push(address(_activeLoan));
// // update s_activeBorrowRequestAddress
// s_activeBorrowRequestAddress = _activeBorrowRequestAddress;
// // update s_activeLendRequestAddress
// s_activeLendRequestAddress = _activeLendRequestAddress;
