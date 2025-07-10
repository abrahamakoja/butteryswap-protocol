// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
// debug
import {Script, console} from "forge-std/Script.sol";

////////////////
/// Imports ///
//////////////

import {LoanConfigLibrary} from "./libraries/LoanConfigLibrary.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// LendRequest_v1 Contract Definition
contract LendRequest_v1 is ReentrancyGuard {
    //////////////
    /// Errors ///
    /////////////

    error LendRequest_v1__UnauthorizedAccess();

    //////////////////////////
    /// Type Declarations ///
    ////////////////////////

    ///////////////
    /**  Enums **/
    /////////////

    /////////////////////////
    /// State variables ////
    ///////////////////////

    address private immutable i_admin;
    mapping(address user => bool isAnOwner) public isOwner;
    address public immutable i_lender;
    using LoanConfigLibrary for LoanConfigLibrary.LendRequest;
    LoanConfigLibrary.LendRequest private s_lendRequest;

    ///////////////
    /// Events ///
    /////////////

    event LoanOffered(address borrower, uint256 LoanAmountRecieved);

    ///////////////////
    /// Modifiers ////
    /////////////////

    modifier onlyLender() {
        if (!isOwner[msg.sender]) revert LendRequest_v1__UnauthorizedAccess();
        if (msg.sender != address(i_lender))
            revert LendRequest_v1__UnauthorizedAccess();
        _;
    }
    modifier onlyAdmin() {
        if (!isOwner[msg.sender]) revert LendRequest_v1__UnauthorizedAccess();
        if (msg.sender != address(i_admin))
            revert LendRequest_v1__UnauthorizedAccess();
        _;
    }

    //////////////////
    /// Functions ///
    ////////////////

    /// @dev contract constructor.
    constructor(
        address[2] memory _owners,
        uint256 amountLended,
        uint256 _timeCreated,
         uint256 SETTLEMENT_FEE
    ) payable {
        s_lendRequest = LoanConfigLibrary.createLendRequest(
            _owners,
            amountLended,
            _timeCreated,
            SETTLEMENT_FEE
        );
        i_lender = _owners[0];
        i_admin = _owners[1];
        isOwner[i_lender] = true;
        isOwner[i_admin] = true;
    }

    receive() external payable {}

    //////////////////////////
    ///External Functions ///
    ////////////////////////

    function cancelRequest() external onlyLender nonReentrant {
        LoanConfigLibrary.cancelLendRequest(
            s_lendRequest,
            address(this),
            s_lendRequest.owners[0]
        );
    }

    function offerLoan(address borrower) external onlyAdmin nonReentrant {
        // transfer eth to an address and transfer tokens to an address
        emit LoanOffered(address(borrower), address(this).balance);
        LoanConfigLibrary.offerLoan(
            s_lendRequest,
            address(borrower),
            address(this).balance
        );
    }

    function addLiquidity() external onlyLender nonReentrant {
        if (msg.sender != address(i_lender)) {
            revert LendRequest_v1__UnauthorizedAccess();
        }
    }

    /////////////////////////////////////////////////
    ///  internal & private view & pure functions ///
    ////////////////////////////////////////////////

    ////////////////////////////////////////////////
    /// External & Public View & Pure Functions ///
    //////////////////////////////////////////////

    function getRequestState()
        external
        view
        returns (LoanConfigLibrary.RequestState)
    {
        return
            LoanConfigLibrary.getLendRequestState(s_lendRequest);
    }

    function getLendRequestDetails()
        external
        view
        returns (
            uint256 amountLended,
            address[2] memory owners,
            uint256 balanceMinusFee,
            uint256 feeEarned,
            LoanConfigLibrary.RequestState state
        )
    {
        return s_lendRequest.getLendRequestDetails();
    }
}
