// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IBorrowRequest {
    function updateRequest(
        address token,
        uint256 index,
        uint256 collateralAmount,
        uint256 _loanAmountRequested
    ) external;

    function updateRequestState(uint8 state) external;

    function acceptLoan(address activeLoan) external;

    function getBorrowRequestDetails()
        external
        view
        returns (
            address[] memory tokens,
            uint256[] memory collateralAmount,
            uint256 loanAmountRequested,
            address borrower,
            uint8 state,
            uint256 timeCreated
        );
}
