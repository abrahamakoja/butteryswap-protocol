// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ILimitMarket {
    function borrow(
        address[] calldata tokens,
        uint256[] calldata collateralAmount,
        uint256 amountToBorrow,
        bool priority
    ) external payable returns (uint8 borrowRequestID);
    // function getPrioritizedBorrowRequestAddress(
    //     uint256 batchLimit,
    //     uint256 numOfResponse
    // ) external view returns (address[] memory prioritizedLoans);
    // function getTotalActiveBorrowRequestContractCount()
    //     external
    //     view
    //     returns (uint256);
    // function getActiveBorrowRequestViaLimit(
    //     uint256 _startIndex,
    //     uint256 _numberOfResponse,
    //     uint256 _batchLimit
    // ) external view returns (address[] memory borrowRequests);
    // function getPrioritizedLendRequestAddress(
    //     uint256 batchLimit,
    //     uint256 numOfResponse
    // ) external view returns (address[] memory prioritizedLoans);
    // function getTotalActiveLendRequestContractCount()
    //     external
    //     view
    //     returns (uint256);
    // function getActiveLendRequestViaLimit(
    //     uint256 _startIndex,
    //     uint256 _numberOfResponse,
    //     uint256 _batchLimit
    // ) external view returns (address[] memory lendRequests);
}
