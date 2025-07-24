// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

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
        address borrower;
        address lender;
        uint256[] collateralAmount;
        address[] tokens;
        uint256 loanAmountRequested;
        uint256 loanOffered;
        uint256 timeCreated;
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
        // delete request.deposit;
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

    /*//////////////////////////////////////////////////////////////
                  ACTIVE LOAN VAULT INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // Public functions for active loan
    function createActiveLoan(
        address _borrower,
        address _lender,
        uint256[] memory _collateralAmount,
        address[] memory _tokens,
        uint256 _loanAmountRequested,
        uint256 _loanOffered,
        uint256 _timeCreated
    ) internal pure returns (ActiveLoanVault memory) {
        return
            ActiveLoanVault({
                borrower: _borrower,
                lender: _lender,
                collateralAmount: _collateralAmount,
                tokens: _tokens,
                loanAmountRequested: _loanAmountRequested,
                loanOffered: _loanOffered,
                timeCreated: _timeCreated
            });
    }

    function getActiveLoanDetails(
        ActiveLoanVault storage request
    )
        internal
        view
        returns (
            address _borrower,
            address _lender,
            uint256[] memory _collateralAmount,
            address[] memory _tokens,
            uint256 _loanAmountRequested,
            uint256 _loanOffered,
            uint256 _timeCreated
        )
    {
        _borrower = request.borrower;
        _lender = request.lender;
        _collateralAmount = request.collateralAmount;
        _tokens = request.tokens;
        _loanAmountRequested = request.loanAmountRequested;
        _loanOffered = request.loanOffered;
        _timeCreated = request.timeCreated;
    }

    
}
