// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BorrowRequest v1
 * @author ButterySwap
 * @notice This contract handles the management of a borrow requests before it is processed by the Enforcer_v1 contract or cancelled by the user.
 * users can top up their loans by adding liquidity to the borrow request but cannot remove the added liquidity unless they decide to cancel the request entirely,
 * by cancelling the request, the user's liquidity is returned to their wallet after a cancellation fee is removed.
 */

// debug
import {Script, console} from "forge-std/Script.sol";

/*//////////////////////////////////////////////////////////////
                                 IMPORT
    //////////////////////////////////////////////////////////////*/

import {LoanConfigLibrary} from "./libraries/LoanConfigLibrary.sol";
import {iProtocolManager} from "./interfaces/iProtocolManager.sol";

contract BorrowRequest_v1 {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error BorrowRequest_v1__UnauthorizedAccess();
    error BorrowRequest_v1__unSupportedToken(address token);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address public immutable i_Borrower;
    iProtocolManager private immutable protocolManager;

    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    using LoanConfigLibrary for LoanConfigLibrary.BorrowRequest;
    LoanConfigLibrary.BorrowRequest private s_borrowRequest;

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
        address borrower,
        uint256[] memory collateralAmount,
        uint256 loanAmountRequested,
        address[] memory token,
        uint256 _timeCreated,
        address _protocolManager
    )  {
        s_borrowRequest = LoanConfigLibrary.createBorrowRequest(
            borrower,
            collateralAmount,
            loanAmountRequested,
            token,
            _timeCreated
        );
        i_Borrower = borrower;
        protocolManager = iProtocolManager(_protocolManager);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function updateRequest(
        address token,
        uint256 index,
        uint256 collateralAmount,
        uint256 _loanAmountRequested
    ) external onlyFactory {
        s_borrowRequest.updateBorrowRequest(
            token,
            index,
            collateralAmount,
            _loanAmountRequested
        );
    }

    function updateRequestState(
        LoanConfigLibrary.RequestState state
    ) external onlyFactory {
        s_borrowRequest.updateBorrowRequestState( state);
       
    }

     function resetRequestDetails() external {
        s_borrowRequest.resetBorrowRequestDetails();
    }

    function acceptLoan(address vault) external onlyEnforcer  {
        emit LoanAccepted(vault);
        s_borrowRequest.acceptLoan( address(vault));
    }

    // Function to get the borrow request details
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
        )
    {
        return s_borrowRequest.getBorrowRequestDetails();
    }
}
