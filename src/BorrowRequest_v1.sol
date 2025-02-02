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

import {LoanRequest} from "./LoanRequest.sol";

contract BorrowRequest_v1 {

    error UnauthorizedTransaction();

    event LoanAccepted(address activeLoan);
    // move token library integration off this contract,only loan request library should remain

    mapping(address => bool) isOwner;
    address[3] public Owners;// replace this with just the borrower refer to lend contract

    using LoanRequest for LoanRequest.BorrowRequest;

    LoanRequest.BorrowRequest private s_borrowRequest;

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert UnauthorizedTransaction();
        _;
    }

    constructor(address[2] memory _owners, uint256 collateral, address memcoinAddress) {
        s_borrowRequest = LoanRequest.createBorrowRequest(_owners, collateral, memcoinAddress);

        for (uint256 i = 0; i < _owners.length; i++) {
            Owners[i] = _owners[i];
            isOwner[_owners[i]] = true;
        }
    }     

    receive() external payable {}

    function getRequestState() public view  returns (LoanRequest.RequestState ) {
        return LoanRequest.getBorrowRequestState(s_borrowRequest);
    }

    // Implement the getTokenBalance function 
    function getTokenBalance() external view returns (uint256) {
        return LoanRequest.getTokenBalance(s_borrowRequest, address(this));
    }

    function getOwners() external view returns (address[2] memory) {
        return LoanRequest.getBorrowOwners(s_borrowRequest);
    }

    function cancelRequest() external onlyOwner {
        LoanRequest.cancelBorrowRequest(s_borrowRequest, address(this));
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
