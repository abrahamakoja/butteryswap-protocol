// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBorrowRequestFactory {
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

    function createBorrowRequest(
        uint256 _collateralAmount,
        uint256 _loanAmountRequested,
        address[] calldata _tokens,
        address[2] calldata _owners,
        bool _priority
    ) external;
}
