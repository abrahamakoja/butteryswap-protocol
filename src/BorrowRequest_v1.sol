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

import {LoanRequest} from "./LoanRequest.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// BorrowRequest_v1 Contract Definition
contract BorrowRequest_v1 is ReentrancyGuard {

     //////////////
    /// Errors ///
    /////////////

    error UnauthorizedAccess();

    //////////////////////////
    /// Type Declarations ///
    ////////////////////////

    ///////////////
    /**  Enums **/
    /////////////

     /////////////////////////
    /// State variables ////
    ///////////////////////
    
    address private immutable i_borrower;
    address private immutable i_admin;
    mapping(address => bool) isOwner;
    // address[2] public Owners;// replace this with just the borrower refer to lend contract
    using LoanRequest for LoanRequest.BorrowRequest;
    LoanRequest.BorrowRequest private s_borrowRequest;

     ///////////////
    /// Events ///
    /////////////

   event LoanAccepted(address activeLoan);
   
    ///////////////////
    /// Modifiers ////
    /////////////////

    modifier onlyBorrower() {
        if (!isOwner[msg.sender] && msg.sender != address(i_borrower)) revert UnauthorizedAccess();
        _;
    }
    modifier onlyAdmin() {
        if (!isOwner[address(i_admin)] && msg.sender != address(i_admin) ) revert UnauthorizedAccess();
        _;
    }

    //////////////////
    /// Functions ///
    ////////////////

    /// @dev contract constructor.
    constructor(address[2] memory _owners, uint256 collateral, address memeCoinAddress) {
        s_borrowRequest = LoanRequest.createBorrowRequest(_owners, collateral, memeCoinAddress);
         i_borrower = _owners[0];
         i_admin = _owners[1];
        isOwner[i_borrower] = true;
        isOwner[i_admin] = true;
    }     

    receive() external payable {}

    //////////////////////////
    ///External Functions ///
    ////////////////////////

    function addLiquidity(address token, uint256 collateralAmount, uint256 requestedAmount) external onlyBorrower nonReentrant{
        
    }

     function cancelRequest() external onlyBorrower nonReentrant {
        LoanRequest.cancelBorrowRequest(s_borrowRequest, address(this));
    }

    function acceptLoan(address multisigAddress) external onlyAdmin nonReentrant{
        emit LoanAccepted(multisigAddress);
        LoanRequest.acceptLoan(s_borrowRequest, address(multisigAddress));
    }
    /////////////////////////////////////////////////
    ///  internal & private view & pure functions ///
    ////////////////////////////////////////////////

    ////////////////////////////////////////////////
    /// External & Public View & Pure Functions ///
    //////////////////////////////////////////////

 function getRequestState() external view  returns (LoanRequest.RequestState ) {
        return LoanRequest.getBorrowRequestState(s_borrowRequest);
    }

    function getEthBalance() external view returns (uint256) {
        return LoanRequest.getBalance(address(this));
    }

    // Function to get the borrow request details
    function getBorrowRequestDetails()
        external
        view
        returns (
            address memeCoin,
            uint256 collateral,
            address[2] memory owners,
            uint256 balanceMinusFee,
            uint256 feeEarned,
            LoanRequest.RequestState state
        )
    {
        return s_borrowRequest.getBorrowRequestDetails();
    }

}
