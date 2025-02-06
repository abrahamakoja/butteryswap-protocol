// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//  debug
import {Script, console} from "forge-std/Script.sol";

////////////////
/// Imports ///
//////////////

import {LendRequest_v1} from "./LendRequest_v1.sol";

contract LendRequestFactory {

    ////////////////
    /// Errors ///
    //////////////

    error LimitMarket_v1_TransferFailed(
        address borrowRequest,
        uint256 sentAmount
    );

    error LimitMarket_v1_InsufficientBalance(
        uint256 balance,
        uint256 collateral
    );
    error LimitMarket_v1_NoAmountSent(uint256 balance, uint256 amountSent);
    error LimitMarket_v1_InvalidAmount(uint256 balance, uint256 amountSent);

    mapping(address loanRequest => bool prioritized)
        private s_loanIsPrioritized;
    mapping(address => address[]) public userToLendRequestContracts;
    LendRequest_v1[] public totalLendRequestArray; //get this and only display the active

    //////////////
    /// Events ///
    ////////////

    event LendRequestCreated(
        address indexed user,
        address indexed multiSigAddress,
        uint256 amountLended
    );

    function createLendRequest( address[2] calldata _owners,
        bool _priority) external payable {
        // checks
        if (msg.value == 0)
            revert LimitMarket_v1_NoAmountSent(msg.sender.balance, msg.value);
        if (msg.value > msg.sender.balance)
            revert LimitMarket_v1_InvalidAmount(msg.sender.balance, msg.value);
        if (msg.value >= msg.sender.balance)
            revert LimitMarket_v1_InsufficientBalance(
                msg.sender.balance,
                msg.value
            );

        // checks to add
        // msg.value should be equal or greater than dollar price of the minimum allowed amount

        rawCreateLendRequest(_owners,_priority);
    }

    function rawCreateLendRequest(
        address[2] calldata owners,
        bool priority
    ) internal {

        // effects
        LendRequest_v1 lendRequest = new LendRequest_v1(owners, msg.value, block.timestamp);

        if (priority == true) {
            s_loanIsPrioritized[address(lendRequest)] = true;
        }
        userToLendRequestContracts[msg.sender].push(address(lendRequest));
        totalLendRequestArray.push(lendRequest);

        // emits
        emit LendRequestCreated(msg.sender, address(lendRequest), msg.value);

        //  interactions
        (bool success, ) = payable(lendRequest).call{
            value: msg.value,
            gas: 2300
        }("");
        if (!success)
            revert LimitMarket_v1_TransferFailed(
                address(lendRequest),
                msg.value
            );
    }

    
}

/***
*add functions
repair loan request library
 */
