// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LoanConfigLibrary} from "../libraries/LoanConfigLibrary.sol";

interface ILendRequest {
    function updateLendRequestState(uint8 state) external;
    function getRequestDetails()
        external
        view
        returns (
            address lender,
            LoanConfigLibrary.RequestState state,
            uint256 timeCreated
        );
    function offerLoan(address borrower, uint256 amount) external;
}
