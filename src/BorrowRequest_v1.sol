// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BorrowRequest v1
 * @author Butteryswap
 * @notice This contract handles the management of a borrow requests before it is processed by the Enforcer_v1 contract or cancelled by the user.
 * users can top up their loans by adding liquidity to the borrow request but cannot remove the added liquity unless they decide to cancel the request entirely,
 * by cancelling the request, the user's liquidity is returned to their wallet after a cancellation fee is removed.
 */

// debug
import {Script, console} from "forge-std/Script.sol";

/*//////////////////////////////////////////////////////////////
                                 IMPORT
    //////////////////////////////////////////////////////////////*/

import {LoanConfigLibrary} from "./libraries/LoanConfigLibrary.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {iProtocolManager} from "./interfaces/iProtocolManager.sol";

contract BorrowRequest_v1 is ReentrancyGuard, Ownable {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error BorrowRequest_v1__UnauthorizedAccess();
    error BorrowRequest_v1__unSupportedToken(address token);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address public immutable i_Borrower;
    mapping(address user => bool isAnOwner) public isOwner;
    iProtocolManager private immutable protocolManager;

    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    using LoanConfigLibrary for LoanConfigLibrary.BorrowRequest;
    LoanConfigLibrary.BorrowRequest public borrowRequest;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event LoanAccepted(address activeLoan);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyEnforcer() {
        if (msg.sender != address(protocolManager.Enforcer()))
            revert BorrowRequest_v1__UnauthorizedAccess();
        _;
    }

    modifier onlyFactory() {
        if (msg.sender != protocolManager.BorrowRequestFactory())
            revert BorrowRequest_v1__UnauthorizedAccess();
        _;
    }

    constructor(
        address _owner,
        uint256[] memory collateralAmount,
        uint256 loanAmountRequested,
        address[] memory token,
        uint256 _timeCreated,
        address _protocolManager
    ) Ownable(_owner) {
        borrowRequest = LoanConfigLibrary.createBorrowRequest(
            _owner,
            collateralAmount,
            loanAmountRequested,
            token,
            _timeCreated
        );
        i_Borrower = _owner;
        isOwner[_owner] = true;
        protocolManager = iProtocolManager(_protocolManager);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    receive() external payable {}

    // function checkCollateralDetails()
    //     external
    //     returns (uint256 numberOfAssets)
    // {
    //     return (borrowRequest.checkCollateralDetails());
    // }

    function updateRequest(
        address token,
        uint256 index,
        uint256 collateralAmount,
        uint256 _loanAmountRequested
    ) external onlyFactory nonReentrant {
        borrowRequest.updateBorrowRequest(
            borrowRequest,
            token,
            index,
            collateralAmount,
            address(this),
            _loanAmountRequested
        );
    }
    function updateState() external onlyFactory {

    }

    function acceptLoan(address vault) external onlyEnforcer nonReentrant {
        emit LoanAccepted(vault);
        borrowRequest.acceptLoan(borrowRequest, address(vault));
    }

    // Function to get the borrow request details
    function getBorrowRequestDetails()
        external
        view
        returns (
            address[] memory tokens,
            uint256 collateralAmount,
            uint256 loanAmountRequested,
            address owner,
            LoanConfigLibrary.RequestState state,
            uint256 timeCreated
        )
    {
        return borrowRequest.getBorrowRequestDetails();
    }
}
