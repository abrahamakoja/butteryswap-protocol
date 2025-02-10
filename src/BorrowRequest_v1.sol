// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BorrowRequest_v1
 * @author Akoja
 * @notice This contract handles the management of a borrow requests before it is processed by the Enforcer_v1 contract or cancelled by the user.
 * users can top up their loans by adding liquidity to the borrow request but cannot remove the added liquity unless they decide to cancel the request entirely,
 * by cancelling the request, the user's liquidity is returned to their wallet after a cancellation fee is removed.
 */

// debug
import {Script, console} from "forge-std/Script.sol";

////////////////
/// Imports ///
//////////////

import {LoanLogicImplementationLibrary} from "./LoanLogicImplementationLibrary.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

///////////////////
/// Interfaces ///
/////////////////

interface ISupportedTokens {
    function checkTokenIsApproved(address token) external view returns (bool);
}

// BorrowRequest_v1 Contract Definition
contract BorrowRequest_v1 is ReentrancyGuard {
    //////////////
    /// Errors ///
    /////////////

    error UnauthorizedAccess(address caller);
    error collateralAssetMaxLimitReached();
    error BorrowRequest_v1__unSupportedToken(address token);
    error providedAssetsOutOfRange(uint256 max, uint256 provided);
    error rangeDataMisMatch();

    //////////////////////////
    /// Type Declarations ///
    ////////////////////////

    ///////////////
    /**  Enums **/
    /////////////

    /////////////////////////
    /// State variables ////
    ///////////////////////

    address public immutable i_borrower;
    address private immutable i_admin;
    uint256 private immutable i_maxAssetLimit;
    ISupportedTokens private immutable supportedTokensContract;
    mapping(address user => bool isAnOwner) private isOwner;
    using LoanLogicImplementationLibrary for LoanLogicImplementationLibrary.BorrowRequest;
    LoanLogicImplementationLibrary.BorrowRequest private s_borrowRequest;

    ///////////////
    /// Events ///
    /////////////

    event LoanAccepted(address activeLoan);

    ///////////////////
    /// Modifiers ////
    /////////////////

    modifier onlyBorrower() {
        if (!isOwner[msg.sender]) revert UnauthorizedAccess(msg.sender);
        if (msg.sender != address(i_borrower))
            revert UnauthorizedAccess(msg.sender);
        _;
    }
    modifier onlyAdmin() {
        if (!isOwner[msg.sender]) revert UnauthorizedAccess(msg.sender);
        if (msg.sender != address(i_admin))
            revert UnauthorizedAccess(msg.sender);
        _;
    }

    //////////////////
    /// Functions ///
    ////////////////

    /// @dev contract constructor.
    constructor(
        address[2] memory _owners,
        uint256 collateralAmount,
        uint256 loanAmountRequested,
        address[3] memory token,
        uint256 _timeCreated,
        uint256 originationFee,
        uint256 _maxAssetLimit,
        address supportedTokensAddress
    ) {
        s_borrowRequest = LoanLogicImplementationLibrary.createBorrowRequest(
            _owners,
            collateralAmount,
            loanAmountRequested,
            token,
            _timeCreated,
            originationFee
        );
        i_borrower = _owners[0];
        i_admin = _owners[1];
        isOwner[i_borrower] = true;
        isOwner[i_admin] = true;
        i_maxAssetLimit = _maxAssetLimit;
        supportedTokensContract = ISupportedTokens(supportedTokensAddress);
    }

    receive() external payable {}

    //////////////////////////
    /// External Functions ///
    ////////////////////////

    function addLiquidity(
        address[] calldata tokens,
        uint256[] calldata collateralAmounts,
        uint256[] calldata _loanAmountRequested
    ) external onlyBorrower nonReentrant {
        //   check asset index to ensure it doesnt exceed 3 revert if it does
        if (
            !(LoanLogicImplementationLibrary.checkCollateralDetails(
                s_borrowRequest
            ) <= i_maxAssetLimit)
        ) {
            revert collateralAssetMaxLimitReached();
        }

        // check if submitted address do not exceed total allowed asset and available slot
        if (
            tokens.length >
            (i_maxAssetLimit -
                LoanLogicImplementationLibrary.checkCollateralDetails(
                    s_borrowRequest
                ))
        ) {
            revert providedAssetsOutOfRange(i_maxAssetLimit, tokens.length);
        }
        if (
            collateralAmounts.length > tokens.length &&
            _loanAmountRequested.length > tokens.length
        ) {
            revert rangeDataMisMatch();
        }
        // check if asset is supported by protocol/ approve and execute transfer within the loop
        for (uint256 i = 0; i > tokens.length; i++) {
            if (supportedTokensContract.checkTokenIsApproved(tokens[i])) {
                revert BorrowRequest_v1__unSupportedToken(address(tokens[i]));
            }

            //  approve tokens
            LoanLogicImplementationLibrary.approveAssets(
                tokens[i],
                collateralAmounts[i]
            );

             //  initiate transfer
            LoanLogicImplementationLibrary.addBorrowLiquidity(
                s_borrowRequest,
                 tokens[i],
                 i,
                collateralAmounts[i],
                address(this),
                _loanAmountRequested[i]
            );
        }
    }

    function cancelRequest() external onlyBorrower nonReentrant {
        // if (msg.sender != i_borrower) {
        //     revert UnauthorizedAccess();
        // }
        LoanLogicImplementationLibrary.cancelBorrowRequest(
            s_borrowRequest,
            address(this)
        );
    }

    function acceptLoan(
        address multisigAddress
    ) external onlyAdmin nonReentrant {
        if (msg.sender != address(i_admin)) {
            revert UnauthorizedAccess(msg.sender);
        }
        emit LoanAccepted(multisigAddress);
        LoanLogicImplementationLibrary.acceptLoan(
            s_borrowRequest,
            address(multisigAddress)
        );
    }

    /////////////////////////////////////////////////
    ///  internal & private view & pure functions ///
    ////////////////////////////////////////////////

    ////////////////////////////////////////////////
    /// External & Public View & Pure Functions ///
    //////////////////////////////////////////////

    function getOwnersAdresses()
        external
        view
        returns (address[2] memory owners)
    {
        owners[0] = i_borrower;
        owners[1] = i_admin;

        console.log("borrower: ", i_borrower);
        console.log("admin: ", i_admin);
        return owners;
    }

    function getRequestState()
        external
        view
        returns (LoanLogicImplementationLibrary.RequestState)
    {
        return
            LoanLogicImplementationLibrary.getBorrowRequestState(
                s_borrowRequest
            );
    }

    // Function to get the borrow request details
    function getBorrowRequestDetails()
        external
        view
        returns (
            address[3] memory tokens,
            uint256 collateralAmount,
            uint256 loanAmountRequested,
            address[2] memory owners,
            uint256 collateralAmountMinusFee,
            uint256 originationFee,
            LoanLogicImplementationLibrary.RequestState state,
            uint256 timeCreated
        )
    {
        return s_borrowRequest.getBorrowRequestDetails();
    }
}
