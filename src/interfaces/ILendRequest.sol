// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ILendRequest {
    function offerLoan(address borrower, uint256 amount) external;

    function updateRequestState(uint8 state) external;

    function updateLendRequestState(uint8 state) external;

    function getRequestDetails()
        external
        view
        returns (address lender, uint8 state, uint256 timeCreated);
}
