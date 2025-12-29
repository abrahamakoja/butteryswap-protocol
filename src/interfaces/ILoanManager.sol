// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ILoanManager {
    function createBorrowRequest(
        address[] calldata tokens,
        uint256[] calldata collateralAmount,
        uint256 amountToBorrow,
        address borrower,
        bool priority
    ) external payable returns (uint256 borrowRequestID);
}
