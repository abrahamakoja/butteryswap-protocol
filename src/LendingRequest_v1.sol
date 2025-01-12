// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
// debug
// import {Script, console} from "forge-std/Script.sol";


import {LoanRequest} from "./LoanRequest.sol"; 

contract LendingRequest_v1 {
    using LoanRequest for LoanRequest.LendRequest;
    LoanRequest.RequestState public loanRequestStatus;

    LoanRequest.LendRequest private s_lendRequest;  

    event LoanOffered(address borrower, uint256 LoanAmountRecieved);

    address public immutable s_lender;

    constructor(address[2] memory _owners, uint256 amountLended) payable {
        s_lendRequest = LoanRequest.createLendRequest(_owners, amountLended);
        s_lender = _owners[0];
        // console.log()
    }

    receive() external payable {}

    function getRequestState() public view  returns (LoanRequest.RequestState ) {
        return LoanRequest.getLendRequestState(s_lendRequest);
    }

    function getOwners() external view returns (address[2] memory) {
        return LoanRequest.getLendOwners(s_lendRequest);
    }

    function cancelRequest() external {
        LoanRequest.cancelLendRequest(s_lendRequest, address(this), s_lendRequest.owners[0]);
        // delete s_lendRequest; 

    }

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
}
