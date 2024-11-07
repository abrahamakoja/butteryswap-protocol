// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LoanRequest} from "./LoanRequest.sol";
       
contract CreateBorrowRequest_v1  {  
 
     error  UnauthorizedTransaction(); 
     event LoanAccepted(address activeLoan);
    // move token library integration off this contract,only loan request library should remain
      mapping(address => bool) isOwner;
      address[3] public Owners;    
     using LoanRequest for LoanRequest.BorrowRequest;
     LoanRequest.BorrowRequest private s_borrowRequest;  
        
     modifier onlyOwner() { 
        if (!isOwner[msg.sender]) revert UnauthorizedTransaction();
        _;        
    }   
      
    constructor(address[3] memory _owners, uint256 collateral,address memcoinAddress) {
        s_borrowRequest = LoanRequest.createBorrowRequest(_owners, collateral,memcoinAddress);
        
          for (uint256 i = 0; i < _owners.length; i++) {  
            Owners[i]=_owners[i];
            isOwner[_owners[i]] = true;      
        }      
    }  
  
    receive() external payable {}

     // Implement the getTokenBalance function from MemeBase   
    function getTokenBalance() external view  returns (uint256) {
       return LoanRequest.getTokenBalance(s_borrowRequest,address(this));
    }

      
    function getOwners() external view  returns (address[3] memory) {
        return LoanRequest.getBorrowOwners(s_borrowRequest);   
    }
          
    function cancelRequest() external onlyOwner {
        LoanRequest.cancelBorrowRequest(s_borrowRequest, address(this));
        delete s_borrowRequest;
    }    
 
    function withdrawTokenBalance(uint256 amount ) external {
        LoanRequest.withdrawBorrowRequestTokenBalance(s_borrowRequest,amount);
    }
       
    function getEthBalance() external view  returns (uint256) {
        return LoanRequest.getBalance(address(this)); 
    }  

     // Function to get the borrow request details
    function getBorrowRequestDetails() external view returns (
        address memeCoin, 
        uint256 collateral, 
        address[3] memory owners, 
        uint256 balanceMinusFee, 
        uint256 feeEarned, 
        LoanRequest.RequestState state
    ) {
        return s_borrowRequest.getBorrowRequestDetails();
    }

    // accept loan function
    function acceptLoan(address multisigAddress) external {
        // transfer eth to an address and transfer tokens to an address
         LoanRequest.acceptLoan(s_borrowRequest,address(multisigAddress));
         emit LoanAccepted(multisigAddress);
        //  revert UnauthorizedTransaction(); 
    }   
      
}  
        