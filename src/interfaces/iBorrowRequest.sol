// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface iBorrowRequest {
    function i_borrower() external view returns (address);

    function Owners(uint256 index) external view returns (address);

    function acceptLoan(address) external;

    function getBorrowRequestDetails()
        external
        view
        returns (
            address memeCoin,
            uint256 collateral,
            address[2] memory owners,
            uint256 balanceMinusFee,
            uint256 feeEarned,
            uint8 state
        );
}
