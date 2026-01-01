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
            /*
            address[] memory tokens,
            uint256[] memory amountDeposited,
            uint256[] memory tokenvalue,
            */
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

    function cancelBorrowRequest(
        address borrower,
        uint256 requestID
    ) external payable;

    function getTotalBorrowRequestCount() external view returns (uint256 count);
    function createLendRequest(
        address lender
    ) external payable returns (uint256 lendRequestID);
    function getLendRequestDetails(
        uint256 _requestID
    )
        external
        view
        returns (
            address lender,
            uint256 amountToLend,
            uint256 timeCreated,
            uint256 DoughBalance,
            uint256 requestID,
            uint8 state
        );
    function cancelLendRequest(
        address lender,
        uint256 requestID
    ) external payable;
}
