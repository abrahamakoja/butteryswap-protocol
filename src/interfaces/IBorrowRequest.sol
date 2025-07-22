// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import {LoanConfigLibrary} from "../libraries/LoanConfigLibrary.sol";
interface IBorrowRequest {
    function acceptLoan(address activeLoan) external;

    function getBorrowRequestDetails()
        external
        view
        returns (
            address[] memory tokens,
            uint256[] memory collateralAmount,
            uint256 loanAmountRequested,
            address borrower,
            LoanConfigLibrary.RequestState state,
            uint256 timeCreated
        );
}
