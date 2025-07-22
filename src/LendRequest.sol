// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
// debug
import {Script, console} from "forge-std/Script.sol";

/*//////////////////////////////////////////////////////////////
                                 IMPORT
    //////////////////////////////////////////////////////////////*/

import {LoanConfigLibrary} from "./libraries/LoanConfigLibrary.sol";
import {iProtocolManager} from "./interfaces/iProtocolManager.sol";

contract LendRequest {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error LendRequest__UnauthorizedAccess();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address public immutable i_lender;
    iProtocolManager private immutable protocolManager;
    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/
    using LoanConfigLibrary for LoanConfigLibrary.LendRequest;
    LoanConfigLibrary.LendRequest private s_lendRequest;

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event LoanOffered(address borrower, uint256 LoanAmountReceived);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyEnforcer() {
        if (msg.sender != address(protocolManager.Enforcer()))
            revert LendRequest__UnauthorizedAccess();
        _;
    }

    modifier onlyFactory() {
        if (msg.sender != protocolManager.LendRequestFactory())
            revert LendRequest__UnauthorizedAccess();
        _;
    }

    /** CONSTRUCTOR */
    constructor(
        address lender,
        uint256 _timeCreated,
        address _protocolManager
    ) payable {
        s_lendRequest = LoanConfigLibrary.createLendRequest(
            lender,
            _timeCreated
        );
        i_lender = lender;
        protocolManager = iProtocolManager(_protocolManager);
    }

    /** RECEIVE FUNCTION */
    receive() external payable {
        if (msg.sender != protocolManager.LendRequestFactory())
            revert LendRequest__UnauthorizedAccess();
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function offerLoan(address borrower) external onlyEnforcer {
        // transfer eth to an address and transfer tokens to an address
        emit LoanOffered(address(borrower), address(this).balance);
        LoanConfigLibrary.offerLoan(
            s_lendRequest,
            address(borrower),
            address(this).balance
        );
    }

    function updateRequestState(
        LoanConfigLibrary.RequestState state
    ) external onlyFactory {
        s_lendRequest.updateLendRequestState( state);
       
    }

    function resetRequestDetails() external onlyFactory {
        s_lendRequest.resetLendRequestDetails();
        //  delete s_lendRequest;
    }

    function getRequestDetails()
        external
        view
        returns (
            address lender,
            LoanConfigLibrary.RequestState state,
            uint256 timeCreated
        )
    {
        return s_lendRequest.getLendRequestDetails();
    }
}
