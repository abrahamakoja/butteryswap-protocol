// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {erc20TokenLibrary} from "./erc20TokenLibrary.sol";

library LoanRequest {

error InsufficientFunds(uint256 balance, uint256 requestedAmount);
error UnauthorizedAccess(address caller, address owner);
error debugging(address);
error executeLoanRequestFailed();

    using erc20TokenLibrary for erc20TokenLibrary.tokenData;

    enum RequestState {
        OPEN,
        CANCELLED,
        CLOSED,
        CANCELLING
    }

    struct BorrowRequest {
        address[] tokens;
        uint256 collateralAmount;
        address[2] owners;
        uint256 collateralAmountMinusFee;
        uint256 feeAmount;
        RequestState state;
        uint256 timeCreated;
    }
    

    struct LendRequest {
        uint256 amountLended;
        address[2] owners;
        uint256 amountLendedMinusFee;
        uint256 feeAmount;
        RequestState state;
         uint256 timeCreated;
    }

    struct ActiveLoan {
        uint256 collateral;
        uint256 amoutToPayBack;
        address[3] owners;
        address memeCoin;
        address borrower;
        address lender;
    }

    // Event declaration
    event FundsWithdrawn(uint256 amount, uint256 balanceAfterFee);
    event contractClosed(address[2] owners, uint256 final_balance);
    event BorrowRequestCreated(erc20TokenLibrary.tokenData token);
    event executionSuccess(address activeBorrower);

    function updateState(BorrowRequest storage request) internal {
      request.state = RequestState.CLOSED;
    }
    function updateLendState(LendRequest storage request) internal {
      request.state = RequestState.CLOSED;
    }

    // Public functions for active loan
    function createActiveLoan(
        address[3] memory _owners,
        uint256 _collateral,
        address memcoinAddress,
        uint256 _amoutToPayBack,
        address _borrower,
        address _lender
    ) internal pure returns (ActiveLoan memory) {
        return ActiveLoan({
            memeCoin: memcoinAddress,
            collateral: _collateral,
            owners: _owners,
            amoutToPayBack: _amoutToPayBack,
            borrower: _borrower,
            lender: _lender
        });
    }
    // Public functions for borrow requests

    function createBorrowRequest(address[2] memory _owners, uint256 _collateral, address[] memory _tokens, uint256 _timeCreated)
        internal
        pure
        returns (BorrowRequest memory)
    {
        return BorrowRequest({
            tokens: _tokens,
            collateralAmount: _collateral,
            owners: _owners,
            collateralAmountMinusFee: 0,
            feeAmount: 0,
            state: RequestState.OPEN,
            timeCreated: _timeCreated
        });
    }

    function addBorrowLiquidity(BorrowRequest storage request,address _token,uint256 _collateralAmount,address contractAddress,uint256 _requestedAmount) internal{
    request.collateralAmount += _requestedAmount;
    request.tokens.push(_token);
       // interactions
        erc20TokenLibrary.transferFromTokens(
            address(_token),
            msg.sender,
            address(contractAddress),
            _collateralAmount
        );
    }

    function cancelBorrowRequest(BorrowRequest storage request, address contractAddress) internal {
        request.state = RequestState.CANCELLING;
        if (request.collateralAmount == 0) revert InsufficientFunds(contractAddress.balance, request.collateralAmount);
        if (request.state == RequestState.OPEN) revert();//do proper reverts
        if (request.state == RequestState.CLOSED) revert(); //do proper reverts;
        // effects
        request.feeAmount =( (request.collateralAmount * 5) / 100 )* 10 ** 18;
        request.collateralAmountMinusFee = (request.collateralAmount - request.feeAmount)* 10 ** 18;

        // Use the token's transfer function from the erc20TokenLibrary
        //  request.state = RequestState.CANCELLED;
        request.state = RequestState.CLOSED;
        emit FundsWithdrawn(request.collateralAmountMinusFee, contractAddress.balance);
        emit contractClosed(request.owners, address(this).balance);

        for (uint256 index = 0; index < request.tokens.length; index++) {
          erc20TokenLibrary.transferTokens(address(request.tokens[index]), address(request.owners[0]), request.collateralAmountMinusFee);
        }
        for (uint256 index = 0; index < request.tokens.length; index++) {
             erc20TokenLibrary.transferTokens(address(request.tokens[index]), address(request.owners[1]), request.feeAmount);
        } 
    }

  
     function getBorrowRequestState(BorrowRequest storage request) internal view returns(RequestState){
        return  request.state;
    }

    function getBorrowOwners(BorrowRequest storage request) internal view returns (address[2] memory) {
        return request.owners;
    }
    // Get contract balance for both borrow and lend request

    function getBalance(address contractAddress) internal view returns (uint256) {
        return contractAddress.balance;
    }
    // get contract balance for borrow request


    // Function to get the details of a BorrowRequest
    function getBorrowRequestDetails(BorrowRequest storage request)
        internal
        view
        returns (
            address[] memory _tokens,
            uint256 collateralAmount,
            address[2] memory owners,
            uint256 collateralAmountMinusFee,
            uint256 feeAmount,
            RequestState state,
            uint256 _timeCreated
        )
    {
        _tokens = request.tokens;
        collateralAmount = request.collateralAmount;
        owners = request.owners;
        collateralAmountMinusFee = request.collateralAmountMinusFee;
        feeAmount = request.feeAmount;
        state = request.state;
        _timeCreated = request.timeCreated;
    }

    // get active loan details
    function getActiveLoanContractDetails(ActiveLoan storage request)
        internal
        view
        returns (
            uint256 collateral,
            uint256 amoutToPayBack,
            address[3] memory owners,
            address memeCoin,
            address borrower,
            address lender
        )
    {
        collateral = request.collateral;
        owners = request.owners;
        amoutToPayBack = request.amoutToPayBack;
        memeCoin = request.memeCoin;
        lender = request.lender;
        borrower = request.borrower;
    }

    /* Public functions for lend requests **/
    function createLendRequest(address[2] memory _owners, uint256 _amountLended, uint256 _timeCreated)
        internal
        pure
        returns (LendRequest memory)
    {
        return LendRequest({
            amountLended: _amountLended,
            owners: _owners,
            amountLendedMinusFee: 0,
            feeAmount: 0,
            state: RequestState.OPEN,
            timeCreated: _timeCreated

        });
    }

    function getLendRequestState(LendRequest storage request) internal view returns(RequestState){
        return  request.state;
    }
 
    // Function to get the details of a lendRequest details
    function getLendRequestDetails(LendRequest storage request)
        internal
        view
        returns (
            uint256 amountLended,
            address[2] memory owners,
            uint256 balanceMinusFee,
            uint256 feeEarned,
            RequestState state
        )
    {
        amountLended = request.amountLended;
        owners = request.owners;
        balanceMinusFee = request.amountLendedMinusFee;
        feeEarned = request.feeAmount; 
        state = request.state;
    }

     function withdrawLendFunds(LendRequest storage request, address contractAddress, address recipient, uint256 amount)
        internal 
    {
        if (request.state == RequestState.OPEN) revert UnauthorizedAccess(contractAddress, contractAddress);
        else if (request.state == RequestState.CANCELLING) request.state = RequestState.CANCELLED;
        else if (request.state == RequestState.CLOSED) revert UnauthorizedAccess(contractAddress, contractAddress);

        emit FundsWithdrawn(amount, request.amountLendedMinusFee);
        (bool success,) = recipient.call{value: amount, gas: 50000}("");
        if (!success) revert InsufficientFunds(contractAddress.balance, amount);
    }


    function cancelLendRequest(LendRequest storage request, address contractAddress, address recipient) internal {
        // checks
        // if (request.amountLended == 0) revert InsufficientFunds(contractAddress.balance, request.amountLended);
        // if (request.amountLended < request.balanceMinusFee) revert InsufficientFunds(contractAddress.balance, request.amountLended);
        // if (request.state == RequestState.OPEN) revert UnauthorizedAccess(contractAddress, contractAddress);
        // if (request.state == RequestState.CANCELLING){ request.state = RequestState.CANCELLED;}
        // if (request.state == RequestState.CLOSED) revert UnauthorizedAccess(contractAddress, contractAddress);

        // // effects
        // request.feeEarned = (request.amountLended * 5) / 1000;
        // request.balanceMinusFee = request.amountLended - request.feeEarned;
        request.state = RequestState.CANCELLING;
        request.state = RequestState.CANCELLED;
        
        // interactions
        (bool success,) = recipient.call{value: 3* 1e18, gas: 50000}("");
        if (!success) revert InsufficientFunds(contractAddress.balance, request.amountLendedMinusFee);
    }

   
    function getLendOwners(LendRequest storage request) internal view returns (address[2] memory) {
        return request.owners;
    }

    // function called by enforcer on each borrow request
    // transfer memecoin to new multisig
    function acceptLoan(BorrowRequest storage request, address multisigAddress) internal {
         request.state = RequestState.CLOSED;
         for (uint256 index = 0; index < request.tokens.length; index++) {
          erc20TokenLibrary.transferTokens(address(request.tokens[index]), address(multisigAddress), request.collateralAmountMinusFee);
        }
        // erc20TokenLibrary.transferTokens(address(request.memeCoin), address(multisigAddress), 10);
    }
    // function called by enforcer on each lend request
    // transfer native currency to borrower

    function offerLoan(LendRequest storage request, address borrowerAddress, uint256 amount) internal {
         request.state = RequestState.CLOSED;
        (bool success,) = borrowerAddress.call{value: amount, gas: 50000}("");
        if (!success) revert InsufficientFunds(address(this).balance, request.amountLendedMinusFee);
    }

    function executeLoan(address activeBorrower) internal {
        emit executionSuccess(activeBorrower);
    }

}
       