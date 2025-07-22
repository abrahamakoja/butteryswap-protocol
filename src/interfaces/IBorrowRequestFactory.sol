// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBorrowRequestFactory {
    function getTotalRequests()
        external
        returns (
            uint256 totalNonPrioritizedBorrowRequests,
            uint256 totalPrioritizedBorrowRequest
        );

    function createRequest(
        uint256[] calldata _collateralAmount,
        uint256 _loanAmountRequested,
        address[] calldata _tokens,
        address _borrower,
        bool _priority
    ) external;

    function prioritizeLoanRequest(
        address borrower,
        address borrowRequest
    ) external;

    function addLiquidity(
        address borrower,
        address borrowRequest,
        address[] calldata tokens,
        uint256[] calldata collateralAmounts,
        uint256 loanAmountRequested
    ) external;

    function cancelRequest(address borrower, address borrowRequest) external;
    function getNonPrioritizedRequestViaIndex(
        uint256 index
    ) external returns (address);
    function getPrioritizedRequestViaIndex(
        uint256 index
    ) external returns (address);
}
