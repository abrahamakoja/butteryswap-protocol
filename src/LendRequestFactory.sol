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

    error LendRequestFactory_TransferFailed(
        address borrowRequest,
        uint256 sentAmount
    );


    mapping(address loanRequest => bool prioritized)
        private s_loanIsPrioritized;
    mapping(address => address[]) public userToLendRequestContracts;
    LendRequest_v1[] public totalLendRequestArray; //get this and only display the active

     receive() external payable {}

    //////////////
    /// Events ///
    ////////////

    event LendRequestCreated(
        address indexed user,
        address indexed multiSigAddress,
        uint256 amountLended
    );

    function createLendRequest(
        address[2] calldata _owners,
        bool _priority
    ) external payable {
       

        rawCreateLendRequest(_owners, _priority);
    }

    function rawCreateLendRequest(
        address[2] calldata owners,
        bool priority
    ) private {
        // effects
        LendRequest_v1 lendRequest = new LendRequest_v1(
            owners,
            msg.value,
            block.timestamp
        );

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
            revert LendRequestFactory_TransferFailed(
                address(lendRequest),
                msg.value
            );
    }

    function getTotalActiveLendRequestContractAddresses()
        public
        view
        returns (address[] memory)
    {
        address[] memory lendRequest = new address[](
            totalLendRequestArray.length
        );
        uint256 counter = 0;
        for (uint256 i = 0; i < totalLendRequestArray.length; i++) {
            LendRequest_v1 lendRequest_v1 = LendRequest_v1(
                payable(address(totalLendRequestArray[i]))
            );
            uint8 status = uint8(lendRequest_v1.getRequestState());
            if (status != 0) {
                continue;
            }
            lendRequest[counter] = address(totalLendRequestArray[i]);
            counter++;
        }

        address[] memory activeLendRequest = new address[](counter);
        for (uint256 i = 0; i < counter; i++) {
            activeLendRequest[i] = lendRequest[i];
        }

        return activeLendRequest;
    }

    function getLendRequestPositionOnActiveRequestQue(
        address lendRequest
    ) external view returns (uint256 position) {
        address[]
            memory lendRequests = getTotalActiveLendRequestContractAddresses();
        for (uint256 i = 0; i < lendRequests.length; i++) {
            if (lendRequests[i] == address(lendRequest)) {
                position = i + 1;
            }
        }
        return position;
    }

    // @dev returns the specific index of an active borrow requests within the array of active borrow request.
    function getActiveLendRequestContractAddressViaIndex(
        uint256 index
    ) external view returns (address borrowRequest) {
        address[]
            memory lendRequests = getTotalActiveLendRequestContractAddresses();
        address targetLendRequestContract;
        for (uint256 i = 0; i < lendRequests.length; i++) {
            if (lendRequests[i] == lendRequests[index]) {
                targetLendRequestContract = address(lendRequests[i]);
            }
        }
        return targetLendRequestContract;
    }

    function getUserToLendRequestAddresses(
        address user
    ) external view returns (address[] memory) {
        return userToLendRequestContracts[user];
    }

    function getPrioritizedLendRequest(
        address LendRequestContractAddress
    ) external view returns (bool isPrioritized) {
        return s_loanIsPrioritized[LendRequestContractAddress];
    }
}
