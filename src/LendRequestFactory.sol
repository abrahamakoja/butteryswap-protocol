// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//  debug
import {Script, console} from "forge-std/Script.sol";

/*//////////////////////////////////////////////////////////////
                                 IMPORT
    //////////////////////////////////////////////////////////////*/

import {LendRequest_v1} from "./LendRequest_v1.sol";
import {iProtocolManager} from "./interfaces/iProtocolManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {LoanConfigLibrary} from "./libraries/LoanConfigLibrary.sol";

contract LendRequestFactory {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error LendRequestFactory__TransferFailed(
        address lendRequest,
        uint256 sentAmount
    );
    error LendRequestFactory__InValidContractAddress();
    error LendRequestFactory__NoAmountSent();
    error LendRequestFactory__InsufficientBalance(
        uint256 balance,
        uint256 amountDeposited
    );

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    iProtocolManager private immutable protocolManager;
    mapping(address loanRequest => bool prioritized)
        private s_loanIsPrioritized;
    mapping(address lender => address[] prioritizedLendRequests)
        private userToLendRequestAddresses;
    mapping(address prioritizedLendRequest => address lender)
        private prioritizedLendRequestToLender;
    mapping(address lendRequest => address lender) private lendRequestToLender;
    mapping(address => address[]) private userToPrioritizedLendRequestAddresses;
    mapping(address => bool) private s_isValidContract;
    LendRequest_v1[] private totalLendRequestArray; //get this and only display the active
    LendRequest_v1[] private s_prioritizedLendRequests;
    mapping(address lender => uint256 totalAmountRequested)
        private lenderToTotalAmountRequested;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event LendRequestCreated(
        address indexed user,
        address indexed multiSigAddress,
        uint256 amountLended
    );

    event LendRequestCancelled(
        address indexed borrower,
        address indexed borrowRequest,
        uint256 indexed borrowRequestBalance
    );

    /** CONSTRUCTOR */
    constructor(address _protocolManager) Ownable(msg.sender) {
        protocolManager = iProtocolManager(_protocolManager);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createRequest(
        address lender,
        bool priority,
        uint256 deposit
    ) external payable {
        uint256 originationFee;
        /** CHECKS */

        if (deposit == 0) revert LendRequestFactory__NoAmountSent();

        if (deposit > lender.balance)
            revert LendRequestFactory__InsufficientBalance(
                lender.balance,
                deposit
            );

        if (deposit < protocolManager.minimumDeposit())
            revert LendRequestFactory__BelowMinimumDeposit();

        originationFee = protocolManager.calculateAmountMinus_OriginationFee(
            deposit
        );

        _rawCreateRequest(lender, priority, deposit, originationFee);
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

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
            revert LendRequestFactory__InValidContractAddress();
        address[]
            memory lendRequests = _getTotalActiveLendRequestContractAddresses();
        for (uint256 i = 0; i < lendRequests.length; i++) {
            if (lendRequests[i] == address(lendRequest)) {
                position = i + 1;
            }
        }
        return position;
    }

    function getTotalActiveLendRequestContractCount()
        external
        view
        returns (uint256 numberOfContracts)
    {
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
            userToLendRequestAddresses[user],
            userToPrioritizedLendRequestAddresses[user]
        );
    }

    function getPrioritizedLendRequest(
        address LendRequestContractAddress
    ) external view returns (bool isPrioritized) {
        return s_loanIsPrioritized[LendRequestContractAddress];
    }

    /*//////////////////////////////////////////////////////////////
                 PUBLIC, PRIVATE AND INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _rawCreateLendRequest(
        address _lender,
        bool _priority,
        uint256 _deposit,
        uint256 _originationFee
    ) private {
        uint256 depositMinusFee = _deposit - _originationFee;
        /** EFFECTS */
        LendRequest_v1 lendRequest = new LendRequest_v1(
            _lender,
            _deposit,
            block.timestamp
        );

        if (priority == true) {
            s_loanIsPrioritized[address(lendRequest)] = true;
            prioritizedLendRequestToLender[lendRequest] = address(_lender);
            s_prioritizedLendRequests.push(lendRequest);
            userToPrioritizedLendRequestAddresses[_lender].push(
                address(lendRequest)
            );
        } else {
            totalLendRequestArray.push(lendRequest);
            lendRequestToLender[lendRequest] = address(_lender);
            userToLendRequestAddresses[msg.sender].push(address(lendRequest));
        }

        lenderToTotalAmountRequested[lender] += _deposit;
        s_isValidContract[address(lendRequest)] = true;

        emit LendRequestCreated(_lender, address(lendRequest), _deposit);

        /** INTERACTIONS */

        /** COLLECT ORIGINATION FEE */
        (bool feePaid, ) = payable(protocolManager.FEE_CONTRACT()).call{
            value: _originationFee
        }("");
        if (!feePaid) revert BorrowRequestFactory__TransferFailed();
        /** TRANSFER tO LEND REQUEST CONTRACT */
        (bool success,) = payable(lendRequest).call{value: depositMinusFee}("");
        if (!success)
            revert LendRequestFactory__TransferFailed(
                address(lendRequest),
                depositMinusFee
            );
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
}
