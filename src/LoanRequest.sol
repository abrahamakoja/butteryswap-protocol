// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;



library LoanRequest {
    // Errors
    // error InvalidOwner();
    // error OwnerNotUnique();
    // error OnlyOwnerAllowed();
    error NoFundsToWithdraw(uint256 balance);
    error StillOpen(address requestContractAddress,uint256 contractBalance );
    error cancelFailed(address requestContractAddress,uint256 contractBalance );
    error TransferFailed(uint256 amount, uint256 balance);
    // error finalTransferFailed(address contractAddress, uint256 contractBalance);

    // Enum for contract states
    enum RequestState {
        OPEN,
        CANCELLING,
        CLOSED
    }
   

    // Struct to store contract data
    struct LendRequest {  
      
        uint256 tokenAmount;
        uint256 feeEarned;
        uint256 interestRate;
        uint256 balanceMinusFee;
        address[] owners;
        mapping(address => bool) isOwner;
    }
 struct BorrowRequest {
      
        uint256 depositedAmount;
        // uint256 collateral;
        // uint256 position;

        // // 
        // uint256 tokenAmount;
        uint256 feeEarned;
        // uint256 interestRate;
        uint256 balanceMinusFee;
        RequestState state;
        address[3] owners;
        // mapping(address => bool) isOwner;
    }
    // Modifier to restrict function calls to owners
    // function onlyOwner(BorrowRequest storage request, address caller) internal view {
    //     if (!request.isOwner[caller]) revert OnlyOwnerAllowed();
    // }

    // Initialize contract data
    function createBorrowRequest(
        address[3] memory _owners,
        uint256 _depositedAmount
        // RequestState _state
        // uint256 _interestRate
    ) internal pure returns (BorrowRequest memory) {
        return BorrowRequest({
              depositedAmount:_depositedAmount,
              owners:_owners,
              balanceMinusFee: 0,
              feeEarned:0,
              state: RequestState.OPEN
        //  collateral: _tokenAmount
        // uint256 tokenAmount;
        // uint256 feeEarned;
        // uint256 interestRate;
        // uint256 balanceMinusFee;
        // ContractState state;
        // address[] owners;
        // mapping(address => bool) isOwner;
        });
        // }
        // request.tokenAmount = _tokenAmount;
        // request.interestRate = _interestRate;
    }

    // Cancel borrow or lending request
    function cancelRequest(BorrowRequest storage request, address contractAddress, address recipient) internal {
         // checks
        if (contractAddress.balance == 0) revert NoFundsToWithdraw(contractAddress.balance);
        request.balanceMinusFee = contractAddress.balance - ((contractAddress.balance * 5) / 1000);
        request.feeEarned = (contractAddress.balance * 5) / 1000;

         if (address(contractAddress).balance < request.balanceMinusFee)
            revert NoFundsToWithdraw( address(contractAddress).balance);

        request.state = RequestState.CANCELLING;
            // interactions
        withdrawFunds(request, contractAddress ,recipient);
       

    }

    // Withdraw funds
    function withdrawFunds(
        BorrowRequest storage request,
        // uint256 _balanceMinusFee,
        address contractAddress,
        address  recipient
    ) internal {
        // if (request.state != RequestState.CANCELLING) revert StillOpen(contractAddress,contractAddress.balance);
        (bool success, ) = recipient.call{value: request.balanceMinusFee}("");
        if (!success) revert TransferFailed(contractAddress.balance, request.balanceMinusFee);

         request.state = RequestState.CLOSED;
         withdrawBalanceToLimitMarketContract(request, contractAddress);
    }
  
    function withdrawBalanceToLimitMarketContract( BorrowRequest storage request, address contractAddress) internal  {
        // checks
        if (!( request.state == RequestState.CLOSED))  revert cancelFailed(contractAddress,contractAddress.balance);
        //  effects  
           request.feeEarned = contractAddress.balance;

        // interactions
        (bool success, ) = request.owners[1].call{
            value: address(contractAddress).balance,
            gas: 50000
        }("");

        if (!success)
        //     revert finalTransferFailed(owners[1], address(this).balance);
        // emit finalBalanceWithdrawn(address(this).balance, owners[1]);

        delete request.owners;
        // emit contractCancelled(owners, address(this).balance);
    }

    // Get all owners of the contract
    function getOwners(BorrowRequest storage request) internal view returns (address[3] memory) {
        return request.owners;
    }

    // Get contract balance
    function getBalance(address contractAddress) internal view returns (uint256) {
        return contractAddress.balance;
    } 


    // Get fees earned
    // function getFeesEarned(BorrowRequest storage self) internal view returns (uint256) {
    //     return self.feeEarned;
    // }
}