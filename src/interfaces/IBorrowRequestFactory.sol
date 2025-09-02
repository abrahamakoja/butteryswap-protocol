// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IBorrowRequestFactory {
    function createRequest(
        uint256[] calldata collateralAmount,
        uint256 loanAmountRequested,
        address[] calldata tokens,
        address borrower,
        bool priority
    ) external payable;

    function prioritizeLoanRequest(
        address borrower,
        address borrowRequest
    ) external payable;

    function addLiquidity(
        address borrower,
        address borrowRequest,
        address[] calldata tokens,
        uint256[] calldata collateralAmounts,
        uint256 loanAmountRequested
    ) external payable;

    function cancelRequest(
        address borrower,
        address borrowRequest
    ) external payable;

    function getTotalRequests()
        external
        view
        returns (
            uint256 totalNonPrioritizedBorrowRequests,
            uint256 totalPrioritizedBorrowRequest
        );

    function getNonPrioritizedRequestViaIndex(
        uint256 index
    ) external view returns (address request);

    function getPrioritizedRequestViaIndex(
        uint256 index
    ) external view returns (address request);
}
