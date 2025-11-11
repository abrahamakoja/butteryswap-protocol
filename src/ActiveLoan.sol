// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LoanConfigLibrary} from "./libraries/LoanConfigLibrary.sol";
import {IProtocolManager} from "./interfaces/IProtocolManager.sol";

contract ActiveLoan {
    using LoanConfigLibrary for LoanConfigLibrary.ActiveLoanVault;

    LoanConfigLibrary.ActiveLoanVault private s_activeLoan;

    error UnauthorizedTransaction();

    address private immutable borrower;
    address private immutable lender;
    IProtocolManager private immutable protocolManager;

    constructor(
        address _borrower,
        address _lender,
        address _protocolManager,
        uint256[] memory collateralAmount,
        address[] memory tokens,
        uint256 loanAmountRequested,
        uint256 loanOffered,
        uint256 timeCreated
    ) {
        borrower = _borrower;
        lender = _lender;
        protocolManager = IProtocolManager(_protocolManager);

        s_activeLoan = LoanConfigLibrary.createActiveLoan(
            _borrower,
            _lender,
            collateralAmount,
            tokens,
            loanAmountRequested,
            loanOffered,
            timeCreated
        );
    }

    receive() external payable {}

    function getDetails()
        external
        view
        returns (
            address _borrower,
            address _lender,
            uint256[] memory _collateralAmount,
            address[] memory _tokens,
            uint256 _loanAmountRequested,
            uint256 _loanOffered,
            uint256 _timeCreated
        )
    {
        return s_activeLoan.getActiveLoanDetails();
    }
}
