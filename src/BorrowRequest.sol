// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title BorrowRequest v1
 * @author ButterySwap
 * @notice This contract handles the management of a borrow requests before it is processed by the loanEnforcer contract or cancelled by the user.
 * users can top up their loans by adding liquidity to the borrow request but cannot remove the added liquidity unless they decide to cancel the request entirely,
 * by cancelling the request, the user's liquidity is returned to their wallet after a cancellation fee is removed.
 */

// debug
import {Script, console} from "forge-std/Script.sol";

/*//////////////////////////////////////////////////////////////
                                 IMPORT
    //////////////////////////////////////////////////////////////*/

import {LoanConfigLibrary} from "./libraries/LoanConfigLibrary.sol";
import {IProtocolManager} from "./interfaces/IProtocolManager.sol";

contract BorrowRequest {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error BorrowRequest__UnauthorizedAccess();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    IProtocolManager private immutable protocolManager;

    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    using LoanConfigLibrary for LoanConfigLibrary.BorrowRequest;
    LoanConfigLibrary.BorrowRequest private s_borrowRequest;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyEnforcer() {
        if (msg.sender != address(protocolManager.Enforcer()))
            revert BorrowRequest__UnauthorizedAccess();
        _;
    }

    modifier onlyFactory() {
        if (msg.sender != protocolManager.BorrowRequestFactory())
            revert BorrowRequest__UnauthorizedAccess();
        _;
    }

    constructor(
        address borrower,
        uint256[] memory collateralAmount,
        uint256 loanAmountRequested,
        address[] memory token,
        uint256 _timeCreated,
        address _protocolManager
    ) {
        s_borrowRequest = LoanConfigLibrary.createBorrowRequest(
            borrower,
            collateralAmount,
            loanAmountRequested,
            token,
            _timeCreated
        );
        protocolManager = IProtocolManager(_protocolManager);
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

    function updateRequestState(uint8 state) external onlyFactory {
        s_borrowRequest.updateBorrowRequestState(state);
    }

    // function resetRequestDetails() internal {
    //     s_borrowRequest.resetBorrowRequestDetails();
    // }

    function acceptLoan(address activeLoan) external onlyEnforcer {
        // emit LoanAccepted(vault);
        // s_borrowRequest.acceptLoan( address(vault));
        // request.state = RequestState.SETTLED;
        // for (uint256 index = 0; index < request.tokens.length; index++) {
        //     erc20TokenLibrary.transferTokens(
        //         address(request.tokens[index]),
        //         address(activeLoanAddress),
        //         request.collateralAmountMinusFee
        //     );
        // }
        // erc20TokenLibrary.transferTokens(address(request.memeCoin), address(multisigAddress), 10);
    }

    // Function to get the borrow request details
    function getRequestDetails()
        external
        view
        returns (
            address[] memory tokens,
            uint256[] memory collateralAmount,
            uint256 loanAmountRequested,
            address borrower,
            uint8 state,
            uint256 timeCreated
        )
    {
        (
            address[] memory _tokens,
            uint256[] memory _collateralAmount,
            uint256 _loanAmountRequested,
            address _borrower,
            LoanConfigLibrary.RequestState _state,
            uint256 _timeCreated
        ) = s_borrowRequest.getBorrowRequestDetails();

        return (
            _tokens,
            _collateralAmount,
            _loanAmountRequested,
            _borrower,
            uint8(_state),
            _timeCreated
        );
    }
}
