// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ILimitMarket {
    function getPrioritizedBorrowRequestAddress(
        uint256 batchLimit,
        uint256 numOfResponse
    ) external view returns (address[] memory prioritizedLoans);
    function getTotalActiveBorrowRequestContractCount()
        external
        view
        returns (uint256);

    function getActiveBorrowRequestViaLimit(
        uint256 _startIndex,
        uint256 _numberOfResponse,
        uint256 _batchLimit
    ) external view returns (address[] memory borrowRequests);

    function getPrioritizedLendRequestAddress(
        uint256 batchLimit,
        uint256 numOfResponse
    ) external view returns (address[] memory prioritizedLoans);
    function getTotalActiveLendRequestContractCount()
        external
        view
        returns (uint256);

    function getActiveLendRequestViaLimit(
        uint256 _startIndex,
        uint256 _numberOfResponse,
        uint256 _batchLimit
    ) external view returns (address[] memory lendRequests);
}
