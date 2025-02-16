// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LoanLogicImplementationLibrary} from "./LoanLogicImplementationLibrary.sol";

contract activeLoan {
    using LoanLogicImplementationLibrary for LoanLogicImplementationLibrary.ActiveLoan;

    LoanLogicImplementationLibrary.ActiveLoan private s_activeLoan;

    error UnauthorizedTransaction();

    event ActiveLoanInitialized(address borrower, address lender, uint256 amountLended, uint256 collateralRecieved);

    mapping(address => bool) private isOwner;
    mapping(address => bool) private isBorrower;
    mapping(address => bool) private isLender;
    // mapping (address  => uint256 ) public borrowerToAmountBorrowed;
    // mapping (address  => uint256 ) public lenderToAmountLended;
    address[3] public Owners;

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert UnauthorizedTransaction();
        _;
    }

    constructor(address[3] memory _owners, uint256 collateral, address memcoinAddress, uint256 amountLended) {
        for (uint256 i = 0; i < _owners.length; i++) {
            Owners[i] = _owners[i];
            isOwner[_owners[i]] = true;
        }
        address _borrower = _owners[0];
        address _lender = _owners[1];
        isBorrower[_borrower] = true;
        isLender[_lender] = true;

        s_activeLoan =
            LoanLogicImplementationLibrary.createActiveLoan(_owners, collateral, memcoinAddress, amountLended, _borrower, _lender);
        emit ActiveLoanInitialized(_borrower, _lender, amountLended, collateral);
    }

    receive() external payable {}

    //  enforcer,borrower and lender
    // struct of both would be passed as well
    //  external function only lender can withdraw if loan is liquidated
    //  external function for borrower to payback and extend
    //  internal function to settle loan and shred after fee withdrawals,
    function getIsOwnerBool(address user) public view returns (bool) {
        return (isOwner[address(user)]);
    }

    function getIsLenderBool(address user) public view returns (bool) {
        return (isLender[address(user)]);
    }

    function getIsBorrowerBool(address user) public view returns (bool) {
        return (isBorrower[address(user)]);
    }

    function getActiveLoanContractDetails()
        external
        view
        returns (
            uint256 collateral,
            uint256 amoutToPayBack,
            address[3] memory owners,
            address memeCoin,
            address borrower,
            address lender
        )
    {
        return s_activeLoan.getActiveLoanContractDetails();
    }
}
