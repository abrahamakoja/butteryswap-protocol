// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details

library LoanConfigLibrary {
    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    struct BorrowRequest {
        address[] tokens;
        uint256[] collateralAmount;
        uint256 loanAmountRequested;
        address borrower;
        RequestState state;
        uint256 timeCreated;
    }

    struct LendRequest {
        address lender;
        RequestState state;
        uint256 timeCreated;
    }

    struct ActiveLoanVault {
        uint256 collateral;
        uint256 amountToPayBack;
        address[3] owners;
        address memeCoin;
        address borrower;
        address lender;
    }

    /*//////////////////////////////////////////////////////////////
                           ENUMS
    //////////////////////////////////////////////////////////////*/
    enum RequestState {
        CLOSED,
        OPEN,
        CANCELLED,
        SETTLED,
        ADDING_LIQUIDITY,
        PRIORITIZING,
        CANCELLING
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                   BORROW REQUEST INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createBorrowRequest(
        address _borrower,
        uint256[] memory _collateralAmount,
        uint256 _loanAmountRequested,
        address[] memory _tokens,
        uint256 _timeCreated
    ) internal pure returns (BorrowRequest memory) {
        return
            BorrowRequest({
                tokens: _tokens,
                collateralAmount: _collateralAmount,
                loanAmountRequested: _loanAmountRequested,
                borrower: _borrower,
                state: RequestState.OPEN,
                timeCreated: _timeCreated
            });
    }

    function updateBorrowRequestState(
        BorrowRequest storage request,
        LoanConfigLibrary.RequestState _state
    ) internal {
        request.state = _state;
    }

    function updateBorrowRequest(
        BorrowRequest storage request,
        address _token,
        uint256 index,
        uint256 _collateralAmount,
        uint256 _loanAmountRequested
    ) internal {
        request.collateralAmount.push(_collateralAmount);
        request.loanAmountRequested += _loanAmountRequested;
        request.tokens[index] = (address(_token));
    }

    function resetBorrowRequestDetails(BorrowRequest storage request) internal {
        delete request.state;
    }

    function acceptLoan(
        BorrowRequest storage request,
        address activeLoanAddress
    ) internal {
        request.state = RequestState.SETTLED;
        for (uint256 index = 0; index < request.tokens.length; index++) {
            // erc20TokenLibrary.transferTokens(
            //     address(request.tokens[index]),
            //     address(activeLoanAddress),
            //     request.collateralAmountMinusFee
            // );
        }
        // erc20TokenLibrary.transferTokens(address(request.memeCoin), address(multisigAddress), 10);
    }

    // Function to get the details of a BorrowRequest
    function getBorrowRequestDetails(
        BorrowRequest storage request
    )
        internal
        view
        returns (
            address[] memory tokens,
            uint256[] memory collateralAmount,
            uint256 loanAmountRequested,
            address borrower,
            RequestState state,
            uint256 timeCreated
        )
    {
        tokens = request.tokens;
        collateralAmount = request.collateralAmount;
        loanAmountRequested = request.loanAmountRequested;
        borrower = request.borrower;
        state = request.state;
        timeCreated = request.timeCreated;
    }

    /*//////////////////////////////////////////////////////////////
                  ACTIVE LOAN VAULT INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // Public functions for active loan
    function createActiveLoan(
        address[3] memory _owners,
        uint256 _collateral,
        address memcoinAddress,
        uint256 _amountToPayBack,
        address _borrower,
        address _lender
    ) internal pure returns (ActiveLoanVault memory) {
        return
            ActiveLoanVault({
                memeCoin: memcoinAddress,
                collateral: _collateral,
                owners: _owners,
                amountToPayBack: _amountToPayBack,
                borrower: _borrower,
                lender: _lender
            });
    }

    function getActiveLoanContractDetails(
        ActiveLoanVault storage request
    )
        internal
        view
        returns (
            uint256 collateral,
            uint256 amountToPayBack,
            address[3] memory owners,
            address memeCoin,
            address borrower,
            address lender
        )
    {
        collateral = request.collateral;
        owners = request.owners;
        amountToPayBack = request.amountToPayBack;
        memeCoin = request.memeCoin;
        lender = request.lender;
        borrower = request.borrower;
    }

    /*//////////////////////////////////////////////////////////////
                    LEND REQUEST INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createLendRequest(
        address _lender,
        uint256 _timeCreated
    ) internal pure returns (LendRequest memory) {
        return
            LendRequest({
                lender: _lender,
                state: RequestState.OPEN,
                timeCreated: _timeCreated
            });
    }

    function updateLendRequestState(
        LendRequest storage request,
        LoanConfigLibrary.RequestState _state
    ) internal {
        request.state = _state;
    }

    function resetLendRequestDetails(LendRequest storage request) internal {
        delete request.state;
        delete request.deposit;
    }

    // Function to get the details of a lendRequest details
    function getLendRequestDetails(
        LendRequest storage request
    )
        internal
        view
        returns (address lender, RequestState state, uint256 timeCreated)
    {
        lender = request.lender;
        state = request.state;
        timeCreated = request.timeCreated;
    }

    function offerLoan(
        LendRequest storage request,
        address borrowerAddress,
        uint256 loanAmountRequested
    ) internal {
        request.state = RequestState.SETTLED;
        // (bool success, ) = borrowerAddress.call{
        //     value: loanAmountRequested
        // }("");
        // if (!success)
        //     revert LoanLogicImplementationLibrary__InsufficientFunds(
        //         address(this).balance,
        //         request.amountLendedMinusFee
        //     );
    }
}
