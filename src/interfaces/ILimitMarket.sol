// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ILimitMarket {
    function borrow(
        address[] calldata tokens,
        uint256[] calldata collateralAmount,
        uint256 amountToBorrow,
        bool priority
    ) external payable returns (uint256 borrowRequestID);
    function increaseCollaterallAmount(
        uint256 requestID,
        address[] calldata tokens,
        uint256[] calldata collateralAmount,
        uint256 amountToBorrow
    ) external payable;
    function prioritizeBorrowRequest(uint256 requestID) external payable;
    function cancelBorrowRequest(uint256 requestID) external payable;
}
