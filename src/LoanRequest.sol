// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {erc20TokenLibrary} from "./erc20TokenLibrary.sol";

error InsufficientFunds(uint256 balance, uint256 requestedAmount);
error UnauthorizedAccess(address caller, address owner);
error debugging(address);
error executeLoanRequestFailed();

library LoanRequest {
    using erc20TokenLibrary for erc20TokenLibrary.tokenData;

    enum RequestState {
        OPEN,
        CANCELLED,
        CLOSED,
        CANCELLING
    }

    struct BorrowRequest {
        address memeCoin;
        uint256 collateral;
        address[3] owners;
        uint256 balanceMinusFee;
        uint256 feeEarned;
        RequestState state;
    }
    // address memecoinAddress;

    struct LendRequest {
        uint256 amountLended;
        address[3] owners;
        uint256 balanceMinusFee;
        uint256 feeEarned;
        RequestState state;
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
    event contractClosed(address[3] owners, uint256 final_balance);
    event BorrowRequestCreated(erc20TokenLibrary.tokenData token);
    event executionSuccess(address activeBorrower);

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

    function createBorrowRequest(address[3] memory _owners, uint256 _collateral, address memcoinAddress)
        internal
        pure
        returns (BorrowRequest memory)
    {
        return BorrowRequest({
            memeCoin: memcoinAddress,
            collateral: _collateral,
            owners: _owners,
            balanceMinusFee: 0,
            feeEarned: 0,
            state: RequestState.OPEN
        });
    }

    //  withdrawTokenBalance function
    function withdrawBorrowRequestTokenBalance(BorrowRequest storage request, uint256 amount) internal {
        if (request.state == RequestState.OPEN) revert UnauthorizedAccess(address(this), msg.sender);
        if (amount == 0 || amount > request.collateral) revert InsufficientFunds(request.collateral, amount);

        // Use the token's transfer function from the erc20TokenLibrary
        erc20TokenLibrary.transferTokens(address(request.memeCoin), address(request.owners[0]), amount);
        emit FundsWithdrawn(amount, request.collateral - amount);
    }

    function cancelBorrowRequest(BorrowRequest storage request, address contractAddress) internal {
        if (request.collateral == 0) revert InsufficientFunds(contractAddress.balance, request.collateral);
        // effects
        request.state = RequestState.CANCELLING;
        request.feeEarned = (request.collateral * 5) / 100;
        request.balanceMinusFee = request.collateral - request.feeEarned;

        // Use the token's transfer function from the erc20TokenLibrary
        erc20TokenLibrary.transferTokens(address(request.memeCoin), address(request.owners[0]), request.balanceMinusFee);
        withdrawBorrowFunds(request, contractAddress, request.owners[1]);
    }

    function withdrawBorrowFunds(BorrowRequest storage request, address contractAddress, address recipient) internal {
        if (request.state == RequestState.OPEN) revert UnauthorizedAccess(contractAddress, recipient);
        else if (request.state == RequestState.CANCELLING) request.state = RequestState.CANCELLED;
        else if (request.state == RequestState.CLOSED) revert UnauthorizedAccess(contractAddress, recipient);

        // Use the token's transfer function from the erc20TokenLibrary
        erc20TokenLibrary.transferTokens(address(request.memeCoin), address(request.owners[1]), request.feeEarned);
        emit FundsWithdrawn(request.balanceMinusFee, contractAddress.balance);
        delete request.owners;
        request.state = RequestState.CLOSED;
        emit contractClosed(request.owners, address(this).balance);
    }

    function getBorrowOwners(BorrowRequest storage request) internal view returns (address[3] memory) {
        return request.owners;
    }
    // Get contract balance for both borrow and lend request

    function getBalance(address contractAddress) internal view returns (uint256) {
        return contractAddress.balance;
    }
    // get contract balance for borrow request

    function getTokenBalance(BorrowRequest storage request, address contractAddress) internal view returns (uint256) {
        return erc20TokenLibrary.getBalance(address(contractAddress), request.memeCoin);
    }
    // Function to get the details of a BorrowRequest

    function getBorrowRequestDetails(BorrowRequest storage request)
        internal
        view
        returns (
            address memeCoin,
            uint256 collateral,
            address[3] memory owners,
            uint256 balanceMinusFee,
            uint256 feeEarned,
            RequestState state
        )
    {
        memeCoin = request.memeCoin;
        collateral = request.collateral;
        owners = request.owners;
        balanceMinusFee = request.balanceMinusFee;
        feeEarned = request.feeEarned;
        state = request.state;
    }

    // Function to get the details of a BorrowRequest
    function getLendRequestDetails(LendRequest storage request)
        internal
        view
        returns (
            uint256 amountLended,
            address[3] memory owners,
            uint256 balanceMinusFee,
            uint256 feeEarned,
            RequestState state
        )
    {
        amountLended = request.amountLended;
        owners = request.owners;
        balanceMinusFee = request.balanceMinusFee;
        feeEarned = request.feeEarned;
        state = request.state;
    }

    //  struct ActiveLoan{
    //     uint256 collateral;
    //     uint256 amoutToPayBack;
    //     address[3] owners;
    //     address memeCoin;
    //     address borrower;
    //     address lender;
    // }

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
    function createLendRequest(address[3] memory _owners, uint256 _amountLended)
        internal
        pure
        returns (LendRequest memory)
    {
        return LendRequest({
            amountLended: _amountLended,
            owners: _owners,
            balanceMinusFee: 0,
            feeEarned: 0,
            state: RequestState.OPEN
        });
    }

    function cancelLendRequest(LendRequest storage request, address contractAddress, address recipient) internal {
        if (request.amountLended == 0) revert InsufficientFunds(contractAddress.balance, request.amountLended);
        request.feeEarned = (request.amountLended * 5) / 1000;
        request.balanceMinusFee = request.amountLended - request.feeEarned;
        if (request.amountLended < request.balanceMinusFee) {
            revert InsufficientFunds(contractAddress.balance, request.amountLended);
        }
        request.state = RequestState.CANCELLING;
        withdrawLendFunds(request, contractAddress, recipient, request.balanceMinusFee);
    }

    function withdrawLendFunds(LendRequest storage request, address contractAddress, address recipient, uint256 amount)
        internal
    {
        if (request.state == RequestState.OPEN) revert UnauthorizedAccess(contractAddress, contractAddress);
        else if (request.state == RequestState.CANCELLING) request.state = RequestState.CANCELLED;
        else if (request.state == RequestState.CLOSED) revert UnauthorizedAccess(contractAddress, contractAddress);

        (bool success,) = recipient.call{value: amount, gas: 50000}("");
        if (!success) revert InsufficientFunds(contractAddress.balance, amount);
        emit FundsWithdrawn(amount, request.balanceMinusFee);
    }

    function getLendOwners(LendRequest storage request) internal view returns (address[3] memory) {
        return request.owners;
    }

    // function called by enforcer on each borrow request
    // transfer memecoin to new multisig
    function acceptLoan(BorrowRequest storage request, address multisigAddress) internal {
        erc20TokenLibrary.transferTokens(address(request.memeCoin), address(multisigAddress), request.collateral);
    }
    // function called by enforcer on each lend request
    // transfer native currency to borrower

    function offerLoan(LendRequest storage request, address borrowerAddress, uint256 amount) internal {
        (bool success,) = borrowerAddress.call{value: amount, gas: 50000}("");
        if (!success) revert InsufficientFunds(address(this).balance, request.balanceMinusFee);
    }

    function executeLoan(address activeBorrower) internal {
        emit executionSuccess(activeBorrower);
    }

    //   function executeLoan(
    //     BorrowRequest storage _borrowRequest,
    //     address activeBorrowRequest,
    //     address activeLoanAddress
    // ) internal {
    //     // Ensure that the borrow request is valid
    //     require(activeBorrowRequest != address(0), "Invalid borrow request address");
    //     require(activeLoanAddress != address(0), "Invalid loan address");

    //     // Ensure that the collateral amount is greater than zero
    //     require(_borrowRequest.collateral > 0, "Collateral must be greater than zero");

    //     // Check allowance (optional, but recommended)
    //     // uint256 allowance = erc20TokenLibrary.allowance(activeBorrowRequest, activeLoanAddress);
    //     // require(allowance >= _borrowRequest.collateral, "Insufficient allowance for transfer");

    //     // Accept loan: transfer collateral to the multisig address
    //     try erc20TokenLibrary.transferFromTokens(
    //         address(_borrowRequest.memeCoin),
    //         address(activeBorrowRequest),
    //         address(activeLoanAddress),
    //         _borrowRequest.collateral
    //     ) {
    //         emit executionSuccess();
    //     } catch {
    //         revert executeLoanRequestFailed();
    //     }

    //     // Offer loan: transfer ETH value from specific lend request contract to the borrower's address
    //     // Uncomment and ensure _lendRequest is defined and initialized properly
    //     /*
    //     (bool success, ) = _borrowRequest.owners[0].call{value:_lendRequest.balanceMinusFee, gas: gasleft()}("");
    //     if (!success) revert executeLoanRequestFailed();
    //     */
    // }
}
