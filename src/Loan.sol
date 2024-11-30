// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {LoanRequest} from "./LoanRequest.sol";

contract Loan {
    
    error NoFundsToWithdraw(uint256 balance, uint256 contractBalance);
    // using LoanRequest for LoanRequest.ContractData;
    using LoanRequest for LoanRequest.BorrowRequest;
    uint256 private tokenAmount;  
    uint256 private interestRate;

    // LoanRequest.ContractData public contractData;
    LoanRequest.BorrowRequest private  s_borrowRequest;

    constructor(
        address[3] memory _owners, 
        uint256 _depositedAmount // uint256 _interestRate
    ) {
        s_borrowRequest = LoanRequest.createBorrowRequest( 
            _owners,
            _depositedAmount 
        );

        // contractData.initializeContract(_owners, _tokenAmount, _interestRate);
    }

    receive() external payable {}   

    function getOwners() external view returns (address[3] memory) {
    //   return s_borrowRequest.owners;
    return  LoanRequest.getOwners(s_borrowRequest);
    }

     function cancelRequest( ) external {
        //   revert NoFundsToWithdraw(msg.sender.balance, address(this).balance);
            LoanRequest.cancelRequest(s_borrowRequest, address(this),msg.sender);
     } 

      // Function to check the contract's balance
    function getBalance() external view  returns (uint256) {
     return LoanRequest.getBalance(address(this));
    }

    // function cancelRequest() external {
    //     LoanRequest.BorrowRequest(msg.sender);
    //     LoanRequest.BorrowRequest(address(this));
    // }

    // function withdraw() external {
    //     BorrowRequest.onlyOwner(msg.sender);
    //     BorrowRequest.withdrawFunds(address(this), payable(msg.sender));
    // }
}
