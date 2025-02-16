// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {erc20TokenLibrary} from "./erc20TokenLibrary.sol";

library LoanLogicImplementationLibrary {
    error LoanLogicImplementationLibrary__InsufficientFunds(
        uint256 balance,
        uint256 requestedAmount
    );
    error LoanLogicImplementationLibrary__UnauthorizedAccess(
        address caller,
        address owner
    );

    // using erc20TokenLibrary for erc20TokenLibrary.tokenData;

    enum RequestState {
        OPEN,
        CANCELLED,
        SETTLED,
        ADDING_LIQUIDITY,
        CANCELLING
    }

    struct BorrowRequest {
        address[] tokens;  
        uint256 collateralAmount;
        uint256 loanAmountRequested;
        address[2] owners;
        uint256 collateralAmountMinusFee;
        uint256 SETTLEMENT_FEE;
        RequestState state;
        uint256 timeCreated;
    }

    struct LendRequest {
        uint256 amountLended;
        address[2] owners;
        uint256 amountLendedMinusFee;
        uint256 SETTLEMENT_FEE;
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

    // Public functions for active loan
    function createActiveLoan(
        address[3] memory _owners,
        uint256 _collateral,
        address memcoinAddress,
        uint256 _amoutToPayBack,
        address _borrower,
        address _lender
    ) internal pure returns (ActiveLoan memory) {
        return
            ActiveLoan({
                memeCoin: memcoinAddress,
                collateral: _collateral,
                owners: _owners,
                amoutToPayBack: _amoutToPayBack,
                borrower: _borrower,
                lender: _lender
            });
    }

    // change to settlement fee
    function calculateSettlementFee(
        uint256 collateralAmount,
        uint256 SETTLEMENT_FEE
    ) internal pure returns (uint256) {
        return (collateralAmount * SETTLEMENT_FEE) / 100;
    }

    function calculateAmountMinusFee(
        uint256 collateralAmount,
        uint256 SETTLEMENT_FEE
    ) internal pure returns (uint256) {
        return
            (collateralAmount -
                (calculateSettlementFee(collateralAmount, SETTLEMENT_FEE))) *
            1e18; //change magic number to precision constant
    }

    function createBorrowRequest(
        address[2] memory _owners,
        uint256 _collateralAmount,
        uint256 _loanAmountRequested,
        address[] memory _tokens,
        uint256 _timeCreated,
        uint256 _SETTLEMENT_FEE
    ) internal pure returns (BorrowRequest memory) {
        return
            BorrowRequest({
                tokens: _tokens,
                collateralAmount: _collateralAmount,
                loanAmountRequested: _loanAmountRequested,
                owners: _owners,
                collateralAmountMinusFee: calculateAmountMinusFee(
                    _collateralAmount,
                    _SETTLEMENT_FEE
                ),
                SETTLEMENT_FEE: _SETTLEMENT_FEE,
                state: RequestState.OPEN,
                timeCreated: _timeCreated
            });
    }

    function checkCollateralDetails(
        BorrowRequest storage request
    ) internal view returns (uint256 numberOfAssets) {
        return (request.tokens.length);
    }

    function approveAssets(address _token, uint256 _collateralAmount) internal {
        erc20TokenLibrary.approveTokens(
            _token,
            address(this),
            _collateralAmount
        );
    }

    function addBorrowLiquidity(
        BorrowRequest storage request,
        address _token,
        uint256 index,
        uint256 _collateralAmount,
        address contractAddress,
        uint256 _loanAmountRequested
    ) internal {
        request.state = RequestState.ADDING_LIQUIDITY;
        request.collateralAmount += _collateralAmount;
        request.loanAmountRequested += _loanAmountRequested;
        request.tokens[index] = (address(_token));

        // interactions
        erc20TokenLibrary.transferFromTokens(
            address(_token),
            msg.sender,
            address(contractAddress),
            _collateralAmount
        );
        request.state = RequestState.OPEN;
    }

    function cancelBorrowRequest(
        BorrowRequest storage request,
        address contractAddress
    ) internal {
        request.state = RequestState.CANCELLING;
        if (request.collateralAmount == 0)
            revert LoanLogicImplementationLibrary__InsufficientFunds(
                contractAddress.balance,
                request.collateralAmount
            );
        if (request.state == RequestState.OPEN) revert(); //do proper reverts
        if (request.state == RequestState.SETTLED) revert(); //do proper reverts;
        // effects
        request.SETTLEMENT_FEE =
            ((request.collateralAmount * 5) / 100) *
            10 ** 18;
        request.collateralAmountMinusFee =
            (request.collateralAmount - request.SETTLEMENT_FEE) *
            10 ** 18;

        // Use the token's transfer function from the erc20TokenLibrary
        //  request.state = RequestState.CANCELLED;
        request.state = RequestState.SETTLED;
        emit FundsWithdrawn(
            request.collateralAmountMinusFee,
            contractAddress.balance
        );
        emit contractClosed(request.owners, address(this).balance);

        for (uint256 index = 0; index < request.tokens.length; index++) {
            erc20TokenLibrary.transferTokens(
                address(request.tokens[index]),
                address(request.owners[0]),
                request.collateralAmountMinusFee
            );
        }
        for (uint256 index = 0; index < request.tokens.length; index++) {
            erc20TokenLibrary.transferTokens(
                address(request.tokens[index]),
                address(request.owners[1]),
                request.SETTLEMENT_FEE
            );
        }
    }

    function getBorrowRequestState(
        BorrowRequest storage request
    ) internal view returns (RequestState) {
        return request.state;
    }

    // Function to get the details of a BorrowRequest
    function getBorrowRequestDetails(
        BorrowRequest storage request
    )
        internal
        view
        returns (
            address[] memory _tokens,
            uint256 collateralAmount,
            uint256 loanAmountRequested,
            address[2] memory owners,
            uint256 collateralAmountMinusFee,
            uint256 SETTLEMENT_FEE,
            RequestState state,
            uint256 _timeCreated
        )
    {
        _tokens = request.tokens;
        collateralAmount = request.collateralAmount;
        loanAmountRequested = request.loanAmountRequested;
        owners = request.owners;
        collateralAmountMinusFee = request.collateralAmountMinusFee;
        SETTLEMENT_FEE = request.SETTLEMENT_FEE;
        state = request.state;
        _timeCreated = request.timeCreated;
    }

    // get active loan details
    function getActiveLoanContractDetails(
        ActiveLoan storage request
    )
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
    // ***********************************************
    /* Public functions for lend requests **/

    function createLendRequest(
        address[2] memory _owners,
        uint256 _amountLended,
        uint256 _timeCreated,
        uint256 _SETTLEMENT_FEE
    ) internal pure returns (LendRequest memory) {
        return
            LendRequest({
                amountLended: _amountLended,
                owners: _owners,
                amountLendedMinusFee:calculateAmountMinusFee(
                    _amountLended,
                    _SETTLEMENT_FEE
                ), 
                SETTLEMENT_FEE: _SETTLEMENT_FEE,
                state: RequestState.OPEN,
                timeCreated: _timeCreated
            });
    }

    function getLendRequestState(
        LendRequest storage request
    ) internal view returns (RequestState) {
        return request.state;
    }

    // Function to get the details of a lendRequest details
    function getLendRequestDetails(
        LendRequest storage request
    )
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
        feeEarned = request.SETTLEMENT_FEE;
        state = request.state;
    }

    function cancelLendRequest(
        LendRequest storage request,
        address contractAddress,
        address recipient
    ) internal {
        // checks
        // if (request.amountLended == 0) revert LoanLogicImplementationLibrary__InsufficientFunds(contractAddress.balance, request.amountLended);
        // if (request.amountLended < request.balanceMinusFee) revert LoanLogicImplementationLibrary__InsufficientFunds(contractAddress.balance, request.amountLended);
        // if (request.state == RequestState.OPEN) revert LoanLogicImplementationLibrary__UnauthorizedAccess(contractAddress, contractAddress);
        // if (request.state == RequestState.CANCELLING){ request.state = RequestState.CANCELLED;}
        // if (request.state == RequestState.SETTLED) revert LoanLogicImplementationLibrary__UnauthorizedAccess(contractAddress, contractAddress);

        // // effects
        // request.feeEarned = (request.amountLended * 5) / 1000;
        // request.balanceMinusFee = request.amountLended - request.feeEarned;
        request.state = RequestState.CANCELLING;
        request.state = RequestState.CANCELLED;

        // interactions
        (bool success, ) = recipient.call{value: 3 * 1e18, gas: 50000}("");
        if (!success)
            revert LoanLogicImplementationLibrary__InsufficientFunds(
                contractAddress.balance,
                request.amountLendedMinusFee
            );
    }

    // function called by enforcer on each borrow request
    // transfer memecoin to new multisig
    function acceptLoan(
        BorrowRequest storage request,
        address activeLoanAddress
    ) internal {
        request.state = RequestState.SETTLED;
        for (uint256 index = 0; index < request.tokens.length; index++) {
            erc20TokenLibrary.transferTokens(
                address(request.tokens[index]),
                address(activeLoanAddress),
                request.collateralAmountMinusFee
            );
        }
        // erc20TokenLibrary.transferTokens(address(request.memeCoin), address(multisigAddress), 10);
    }

    // function called by enforcer on each lend request
    // transfer native currency to borrower

    function offerLoan(
        LendRequest storage request,
        address borrowerAddress,
        uint256 loanAmountRequested
    ) internal {
        request.state = RequestState.SETTLED;
        (bool success, ) = borrowerAddress.call{
            value: loanAmountRequested,
            gas: 50000
        }("");
        if (!success)
            revert LoanLogicImplementationLibrary__InsufficientFunds(
                address(this).balance,
                request.amountLendedMinusFee
            );
    }
}
