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

    error UnauthorizedTransaction();

    //////////////////////////
    /// Type Declarations ///
    ////////////////////////

    ///////////////
    /**  Enums **/
    /////////////

     /////////////////////////
    /// State variables ////
    ///////////////////////

    mapping(address => bool) isOwner;
    address[3] public Owners;// replace this with just the borrower refer to lend contract
    using LoanRequest for LoanRequest.BorrowRequest;
    LoanRequest.BorrowRequest private s_borrowRequest;

     ///////////////
    /// Events ///
    /////////////

   event LoanAccepted(address activeLoan);
   
    ///////////////////
    /// Modifiers ////
    /////////////////

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert UnauthorizedTransaction();
        _;
    }

    //////////////////
    /// Functions ///
    ////////////////

    /// @dev contract constructor.
    constructor(address[2] memory _owners, uint256 collateral, address memeCoinAddress) {
        s_borrowRequest = LoanRequest.createBorrowRequest(_owners, collateral, memeCoinAddress);

        for (uint256 i = 0; i < _owners.length; i++) {
            Owners[i] = _owners[i];
            isOwner[_owners[i]] = true;
        }
    }     

    receive() external payable {}

    //////////////////////////
    ///External Functions ///
    ////////////////////////

     function cancelRequest() external onlyOwner nonReentrant {
        LoanRequest.cancelBorrowRequest(s_borrowRequest, address(this));
    }

    /////////////////////////////////////////////////
    ///  internal & private view & pure functions ///
    ////////////////////////////////////////////////

    ////////////////////////////////////////////////
    /// External & Public View & Pure Functions ///
    //////////////////////////////////////////////

 function getRequestState() public view  returns (LoanRequest.RequestState ) {
        return LoanRequest.getBorrowRequestState(s_borrowRequest);
    }

    // Implement the getTokenBalance function 
    function getTokenBalance() public view returns (uint256) {
        return LoanRequest.getTokenBalance(s_borrowRequest, address(this));
    }

    function getOwner() public view returns (address[2] memory) {
        return LoanRequest.getBorrowOwners(s_borrowRequest);
    }
   

   

    function withdrawTokenBalance(uint256 amount) external {
        LoanRequest.withdrawBorrowRequestTokenBalance(s_borrowRequest, amount);
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

    // accept loan function
    function acceptLoan(address multisigAddress) external {
        // transfer eth to an address and transfer tokens to an address
        emit LoanAccepted(multisigAddress);
        LoanRequest.acceptLoan(s_borrowRequest, address(multisigAddress));
        //  revert UnauthorizedTransaction();
    }

    function updateState() external{
        LoanRequest.updateState(s_borrowRequest);
    }
}
