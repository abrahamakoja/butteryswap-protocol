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
        address lendRequest,
        uint256 sentAmount
    );
    error inValidContractAddress();

    mapping(address loanRequest => bool prioritized)
        private s_loanIsPrioritized;
    mapping(address => address[]) public userToLendRequestContracts;
    mapping(address => address[]) private userToPrioritizedLendRequestContracts;
    mapping(address => bool) private s_isValidContract;
    LendRequest_v1[] public totalLendRequestArray; //get this and only display the active
    LendRequest_v1[] public s_prioritizedLendRequests;

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
        _rawCreateLendRequest(_owners, _priority);
    }

    function _rawCreateLendRequest(
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
            s_prioritizedLendRequests.push(lendRequest);
            userToPrioritizedLendRequestContracts[msg.sender].push(
                address(lendRequest)
            );
        } else {
            totalLendRequestArray.push(lendRequest);
        }

        userToLendRequestContracts[msg.sender].push(address(lendRequest));
        s_isValidContract[address(lendRequest)] = true;
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

    // getters

    function getTotalActivePrioritizedLendRequests(
        uint256 _batchLimit,
        uint256 numOfResponse
    ) external view returns (address[] memory) {
        uint256 total = s_prioritizedLendRequests.length;
        uint256 limit = total > _batchLimit ? _batchLimit : total;
        address[] memory lendRequest = new address[](
            s_prioritizedLendRequests.length
        );
        uint256 counter = 0;

        for (uint256 i = 0; i < limit; i++) {
            LendRequest_v1 lendRequest_v1 = LendRequest_v1(
                payable(address(s_prioritizedLendRequests[i]))
            );
            uint8 status = uint8(lendRequest_v1.getRequestState());
            if (status != 0) {
                continue;
            }
            lendRequest[counter] = address(s_prioritizedLendRequests[i]);
            if (lendRequest.length == numOfResponse) {
                break;
            }
            counter++;
        }

        //  console.log(numOfResponse);
        //  console.log(total);
        //   console.log(limit);
        //   console.log(_batchLimit);

        address[] memory activePrioritizedLendRequests = new address[](counter);
        for (uint256 i = 0; i < counter; i++) {
            activePrioritizedLendRequests[i] = lendRequest[i];
            // console.log(address(activePrioritizedLendRequests[i]));
        }
        return activePrioritizedLendRequests;
    }

    function getBatchedActiveLendRequestAddresses(
        uint256 startIndex,
        uint256 numberOfResponse,
        uint256 _batchLimit
    ) external view returns (address[] memory) {
        uint256 total = _getTotalActiveLendRequestContractAddresses().length;
        uint256 _startIndex = startIndex > total ? 0 : startIndex;
        uint256 limit = total > _batchLimit ? _batchLimit : total;
        uint256 _numberOfResponse = numberOfResponse > limit
            ? limit
            : numberOfResponse;
        address[]
            memory activeLendRequests = _getTotalActiveLendRequestContractAddresses();
        address[] memory batchedLendRequests = new address[](_numberOfResponse);

        // console.log(total);
        // console.log(limit);

        for (uint256 i = _startIndex; i < _numberOfResponse; i++) {
            if (i < startIndex) {
                continue;
            }
            batchedLendRequests[i] = activeLendRequests[i];

            if (i > limit) {
                break;
            }
        }
        return batchedLendRequests;
    }

    function _getTotalActiveLendRequestContractAddresses()
        private
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

    function getTotalActiveLendRequestAddress()
        external
        view
        returns (uint256 numberOfResponse)
    {
        return _getTotalActiveLendRequestContractAddresses().length;
    }

    function getLendRequestPositionOnActiveRequestQue(
        address lendRequest
    ) external view returns (uint256 position) {
        if (s_isValidContract[lendRequest] == false)
            revert inValidContractAddress();
        address[]
            memory lendRequests = _getTotalActiveLendRequestContractAddresses();
        for (uint256 i = 0; i < lendRequests.length; i++) {
            if (lendRequests[i] == address(lendRequest)) {
                position = i + 1;
            }
        }
        return position;
    }

    function getTotalActiveLendRequestContractCount() external view returns(uint256 numberOfContracts){
       return _getTotalActiveLendRequestContractAddresses().length;
    }

    function getUserToLendRequestAddresses(
        address user
    )
        external
        view
        returns (
            address[] memory lendRequestAddresses,
            address[] memory prioritizedLendRequestContracts
        )
    {
        return (
            userToLendRequestContracts[user],
            userToPrioritizedLendRequestContracts[user]
        );
    }

    function getPrioritizedLendRequest(
        address LendRequestContractAddress
    ) external view returns (bool isPrioritized) {
        return s_loanIsPrioritized[LendRequestContractAddress];
    }
}
