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

    error UnauthorizedAccess(address caller);

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
    mapping(address user => bool isAnOwner) private isOwner;
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
         if (!isOwner[msg.sender] ) revert UnauthorizedAccess(msg.sender);
        if ( msg.sender != address(i_borrower)) revert UnauthorizedAccess(msg.sender);
        _;
    }
    modifier onlyAdmin() {
         if (!isOwner[msg.sender] ) revert UnauthorizedAccess(msg.sender);
        if ( msg.sender != address(i_admin) ) revert UnauthorizedAccess(msg.sender);
        _;
    }

    //////////////////
    /// Functions ///
    ////////////////

    /// @dev contract constructor.
    constructor(address[2] memory _owners, uint256 collateralAmount, address[] memory token, uint256 _timeCreated) {
        
        s_borrowRequest = LoanRequest.createBorrowRequest(_owners, collateralAmount, token, _timeCreated);
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
        // if (msg.sender != address(i_borrower)) {
        //     revert UnauthorizedAccess();
        // } 
        LoanRequest.addBorrowLiquidity(s_borrowRequest,token,collateralAmount,address(this),requestedAmount);
    }

     function cancelRequest() external onlyBorrower nonReentrant {
        // if (msg.sender != i_borrower) {
        //     revert UnauthorizedAccess();
        // } 
        LoanRequest.cancelBorrowRequest(s_borrowRequest, address(this));
    }

    function acceptLoan(address multisigAddress) external onlyAdmin nonReentrant{
         if (msg.sender != address(i_admin)) {
            revert UnauthorizedAccess(msg.sender);
        } 
        emit LoanAccepted(multisigAddress);
        LoanRequest.acceptLoan(s_borrowRequest, address(multisigAddress));
    }

    /////////////////////////////////////////////////
    ///  internal & private view & pure functions ///
    ////////////////////////////////////////////////

    ////////////////////////////////////////////////
    /// External & Public View & Pure Functions ///
    //////////////////////////////////////////////

    function getOwnersAdresses() external view returns(address[2] memory owners){
        owners[0]=i_borrower;
        owners[1]=i_admin;

        console.log("borrower: ",i_borrower);
        console.log("admin: ",i_admin);
        return owners;
    }

 function getRequestState() external view  returns (LoanRequest.RequestState ) {
        return LoanRequest.getBorrowRequestState(s_borrowRequest);
    }

    // Function to get the borrow request details
    function getBorrowRequestDetails()
        external
        view
        returns (
            address[] memory tokens,
            uint256 collateralAmount,
            address[2] memory owners,
            uint256 collateralAmountMinusFee,
            uint256 feeAmount,
            LoanRequest.RequestState state,
            uint256 timeCreated
        )
    {
        return s_borrowRequest.getBorrowRequestDetails();
    }


}