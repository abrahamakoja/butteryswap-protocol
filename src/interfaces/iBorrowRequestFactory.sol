// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface iBorrowRequestFactory {
    function getTotalActiveBorrowRequestContractCount()
        external
        view
        returns (uint256 numberOfContracts);
    function getBorrowRequestPositionOnActiveRequestQue(
        address borrowRequest
    ) external view returns (uint256 position);

    function getTotalActivePrioritizedBorrowRequests(
        uint256 _batchLimit,
        uint256 numOfResponse
    ) external view returns (address[] memory);

    function getBatchedActiveBorrowRequestContractAddresses(
        uint256 startIndex,
        uint256 numberOfResponse,
        uint256 _batchLimit
    ) external view returns (address[] memory);

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
}
