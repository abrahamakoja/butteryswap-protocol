// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
// debug
// import {Script, console} from "forge-std/Script.sol";

////////////////
/// Imports ///
//////////////

import {LoanRequest} from "./LoanRequest.sol"; 
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// BorrowRequest_v1 Contract Definition
contract LendingRequest_v1 is ReentrancyGuard {

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


    address private immutable i_admin;
    mapping(address user => bool isAnOwner) public isOwner;
    address public immutable i_lender;
    using LoanRequest for LoanRequest.LendRequest;
    LoanRequest.LendRequest private s_lendRequest;  



     ///////////////
    /// Events ///
    /////////////

    event LoanOffered(address borrower, uint256 LoanAmountRecieved);

    ///////////////////
    /// Modifiers ////
    /////////////////

    modifier onlyBorrower() {
        if (!isOwner[msg.sender] ) revert UnauthorizedAccess();
        _;
    }
    modifier onlyAdmin() {
        if (!isOwner[msg.sender] && msg.sender != address(i_admin) ) revert UnauthorizedAccess();
        _;
    }

    //////////////////
    /// Functions ///
    ////////////////

    /// @dev contract constructor.
    constructor(address[2] memory _owners, uint256 amountLended) payable {
        s_lendRequest = LoanRequest.createLendRequest(_owners, amountLended);
        i_lender = _owners[0];
        i_admin = _owners[1];
         isOwner[i_lender] = true;
         isOwner[i_admin] = true;
    }

    receive() external payable {}

     //////////////////////////
    ///External Functions ///
    ////////////////////////

    function getRequestState() external view  returns (LoanRequest.RequestState ) {
        return LoanRequest.getLendRequestState(s_lendRequest);
    }

    function getOwners() external view returns (address[2] memory) {
        return LoanRequest.getLendOwners(s_lendRequest);
    }

    function cancelRequest() external {
        LoanRequest.cancelLendRequest(s_lendRequest, address(this), s_lendRequest.owners[0]);
        // delete s_lendRequest; 

    }

     /////////////////////////////////////////////////
    ///  internal & private view & pure functions ///
    ////////////////////////////////////////////////

    ////////////////////////////////////////////////
    /// External & Public View & Pure Functions ///
    //////////////////////////////////////////////

    function getBalance() external view returns (uint256) {
        return LoanRequest.getBalance(address(this));
    }

    function offerLoan(address borrower) external {
        // transfer eth to an address and transfer tokens to an address
        LoanRequest.offerLoan(s_lendRequest, address(borrower), address(this).balance);
        emit LoanOffered(address(borrower), address(this).balance);
    }  

    // Function to get the borrow request details
    function getLendRequestDetails()
        external
        view
        returns (
            uint256 amountLended,
            address[2] memory owners,
            uint256 balanceMinusFee,
            uint256 feeEarned,
            LoanRequest.RequestState state
        )
    {
        return s_lendRequest.getLendRequestDetails();
    }


     function updateState() external{
        LoanRequest.updateLendState(s_lendRequest);
    }
}
