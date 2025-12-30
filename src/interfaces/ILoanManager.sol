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

    function getBorrowRequestDetails(
        uint256 borrowRequestID
    )
        external
        view
        returns (
            address borrower,
            uint256 amountToBorrow,
            bool priority,
            uint256 timeCreated,
            uint256 interestRate,
            uint256 dueDate,
            uint256 BreadBalance,
            uint256 requestID,
            address[] memory tokens,
            uint256[] memory amountDeposited,
            uint256[] memory tokenvalue,
            uint8 state
        );
    function getBorrowerRequestsDetails(
        address borrower
    ) external view returns (uint256[] memory requestsID);
    function increaseCollaterallAmount(
        address borrower,
        uint256 requestID,
        address[] calldata tokens,
        uint256[] calldata collateralAmounts,
        uint256 amountToBorrow
    ) external payable;
    function prioritizeBorrowRequest(
        address borrower,
        uint256 requestID
    ) external payable;

    function isRequestPrioritized(
        uint256 requestID
    ) external view returns (bool);
}
