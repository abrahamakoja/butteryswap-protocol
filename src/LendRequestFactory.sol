// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//  debug @audit
import {Script, console} from "forge-std/Script.sol";

/*//////////////////////////////////////////////////////////////
                                 IMPORT
    //////////////////////////////////////////////////////////////*/

import {LendRequest_v1} from "./LendRequest_v1.sol";
import {iProtocolManager} from "./interfaces/iProtocolManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {LoanConfigLibrary} from "./libraries/LoanConfigLibrary.sol";

contract LendRequestFactory is Ownable {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error LendRequestFactory__TransferFailed(
        address lendRequest,
        uint256 amountDeposited
    );
    error LendRequestFactory__InValidContractAddress();
    error LendRequestFactory__NoAmountSent();
    error LendRequestFactory__InsufficientBalance(
        uint256 balance,
        uint256 amountDeposited
    );
    error BorrowRequestFactory__UnAuthorized();
    error LendRequestFactory__BelowMinimumDeposit();
    error LendRequestFactory__RequestNotOpen();
    error LendRequestFactory__inValidRequest();
    error LendRequestFactory__notOwner();
    error LendRequestFactory__CancellationFeePaymentFailed();
    error LendRequestFactory__OriginationFeePaymentFailed();
    error LendRequestFactory__LendRequestCancellationFailed(
        uint256 lendRequestContractBalance
    );
    error LendRequestFactory__RequestIsPrioritized();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    //  LendRequest_v1 lendRequest_v1;
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
    LendRequest_v1[] private s_totalUnPrioritizedLendRequest;
    LendRequest_v1[] private s_prioritizedLendRequests;
    mapping(address lender => uint256 totalAmountRequested)
        private lenderToTotalAmountRequested;
    mapping(address prioritizedLendRequest => uint256 position)
        private lendRequestToPositionOnPrioritizedList;
    mapping(address nonPrioritizedLendRequest => uint256 position)
        private lendRequestToPositionOnNonPrioritizedList;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyLimitMarket() {
        if (msg.sender != protocolManager.LimitMarket()) {
            revert BorrowRequestFactory__UnAuthorized();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event LendRequestCreated(
        address indexed user,
        address indexed borrowRequestAddress,
        uint256 deposit
    );

    event LendRequestCancelled(
        address indexed lender,
        address indexed lendRequestAddress,
        uint256 indexed depositedAmount,
        uint256 lendRequestBalance
    );
    event LendRequestUpdated(
        address indexed lendRequestAddress,
        uint256 indexed depositedAmount
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
    ) external payable onlyLimitMarket {
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

    function prioritizeLoanRequest(
        address lender,
        address payable lendRequest
    ) external payable onlyLimitMarket {
        // check if loan request is valid
        if (s_isValidContract[lendRequest] == false)
            revert LendRequestFactory__inValidRequest();
        // check if request is prioritized
        if (s_loanIsPrioritized[lendRequest] == true)
            revert LendRequestFactory__RequestIsPrioritized();
        //get loan details
        (
            ,
            address _lender,
            LoanConfigLibrary.RequestState _state,

        ) = _getLendRequestDetails(lendRequest);
        // check if loan is open
        if (_state != LoanConfigLibrary.RequestState.OPEN)
            revert LendRequestFactory__RequestNotOpen();
        LoanConfigLibrary.RequestState state = LoanConfigLibrary
            .RequestState
            .PRIORITIZING;
        LendRequest_v1(payable(lendRequest)).updateRequestState(state);

        // check if lender is authorized to interact with loan
        if (
            lendRequestToLender[lendRequest] != address(lender) ||
            prioritizedLendRequestToLender[lendRequest] != address(lender) ||
            address(lender) != address(_lender)
        ) revert LendRequestFactory__notOwner();

        _rawPrioritizeLoanRequest(lendRequest, lender);
    }

    function _rawPrioritizeLoanRequest(
        address payable _lendRequest,
        address _lender
    ) private {
        uint256 precision = protocolManager.INDEX_PRECISION();
        // change mapping
        lendRequestToLender[_lendRequest] = address(0);
        delete userToLendRequestAddresses[_lender];
        delete s_totalUnPrioritizedLendRequest[
            lendRequestToPositionOnNonPrioritizedList[_lendRequest]
        ];
        delete lendRequestToPositionOnNonPrioritizedList[_lendRequest];

        // update state

        // set prioritized mappings
        s_loanIsPrioritized[address(_lendRequest)] = true;
        prioritizedLendRequestToLender[_lendRequest] = address(_lender);
        s_prioritizedLendRequests.push(LendRequest_v1(_lendRequest));
        userToPrioritizedLendRequestAddresses[_lender].push(
            address(_lendRequest)
        );
        lendRequestToPositionOnPrioritizedList[_lendRequest] =
            s_prioritizedLendRequests.length +
            precision;

        LoanConfigLibrary.RequestState state = LoanConfigLibrary
            .RequestState
            .OPEN;
        LendRequest_v1(_lendRequest).updateRequestState(state);
        // pay fee
    }

    function addLiquidity(
        address lender,
        uint256 deposit,
        address payable lendRequest
    ) external payable onlyLimitMarket {
        // check if loan request is valid
        if (s_isValidContract[lendRequest] == false)
            revert LendRequestFactory__inValidRequest();
        //get loan details
        (
            ,
            address _lender,
            LoanConfigLibrary.RequestState _state,

        ) = _getLendRequestDetails(lendRequest);
        // check if loan is open
        if (_state != LoanConfigLibrary.RequestState.OPEN)
            revert LendRequestFactory__RequestNotOpen();
        LoanConfigLibrary.RequestState state = LoanConfigLibrary
            .RequestState
            .ADDING_LIQUIDITY;
        LendRequest_v1(lendRequest).updateRequestState(state);

        // check if lender is authorized to interact with loan
        if (
            lendRequestToLender[lendRequest] != address(lender) ||
            prioritizedLendRequestToLender[lendRequest] != address(lender) ||
            address(lender) != address(_lender)
        ) revert LendRequestFactory__notOwner();

        _rawAddLiquidity(lender, deposit, lendRequest);
    }

    function cancelRequest(
        address lender,
        address payable lendRequest
    ) external payable onlyLimitMarket {
        // check if loan request is valid'
        if (s_isValidContract[lendRequest] == false)
            revert LendRequestFactory__inValidRequest();
        //get loan details
        (
            uint256 _deposit,
            address _lender,
            LoanConfigLibrary.RequestState _state,

        ) = _getLendRequestDetails(lendRequest);
        // check if loan is open
        if (_state != LoanConfigLibrary.RequestState.OPEN)
            revert LendRequestFactory__RequestNotOpen();
        LoanConfigLibrary.RequestState state = LoanConfigLibrary
            .RequestState
            .CANCELLING;
        LendRequest_v1(lendRequest).updateRequestState(state);

        // check if lender is authorized to interact with loan
        if (
            lendRequestToLender[lendRequest] != address(lender) ||
            prioritizedLendRequestToLender[lendRequest] != address(lender) ||
            address(lender) != address(_lender)
        ) revert LendRequestFactory__notOwner();

        _rawCancelRequest(lender, lendRequest, _deposit);
    }

    /*//////////////////////////////////////////////////////////////
                    EXTERNAL  VIEW FUNCTIONS 
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
            uint8 status = _getLendRequestDetails(address(lendRequest_v1));
            if (status != 0) {
                continue;
            }     
            lendRequest[counter] = address(s_prioritizedLendRequests[i]);
            if (lendRequest.length == numOfResponse) {
                break;
            }
            counter++;//check
        }

        address[] memory activePrioritizedLendRequests = new address[](counter);
        for (uint256 i = 0; i < counter; i++) {
            activePrioritizedLendRequests[i] = lendRequest[i];
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

    function _rawCreateRequest(
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
            block.timestamp,
              address(protocolManager)
        );

        if (_priority == true) {
            s_loanIsPrioritized[address(lendRequest)] = true;
            prioritizedLendRequestToLender[address(lendRequest)] = address(_lender);
            s_prioritizedLendRequests.push(lendRequest);
            userToPrioritizedLendRequestAddresses[_lender].push(
                address(lendRequest)
            );
            lendRequestToPositionOnPrioritizedList[address(lendRequest)] =
                s_prioritizedLendRequests.length +
                protocolManager.INDEX_PRECISION();
        } else {
            s_totalUnPrioritizedLendRequest.push(lendRequest);
            lendRequestToLender[lendRequest] = address(_lender);
            userToLendRequestAddresses[_lender].push(address(lendRequest));
            lendRequestToPositionOnNonPrioritizedList[address(lendRequest)] =
                s_totalUnPrioritizedLendRequest.length +
                protocolManager.INDEX_PRECISION();
        }

        lenderToTotalAmountRequested[_lender] += _deposit;
        s_isValidContract[address(lendRequest)] = true;

        /** EMIT EVENTS */
        emit LendRequestCreated(_lender, address(lendRequest), _deposit);

        /** INTERACTIONS */

        /** COLLECT ORIGINATION FEE */
        (bool feePaid, ) = payable(protocolManager.FEE_CONTRACT()).call{
            value: _originationFee
        }("");
        if (!feePaid) revert LendRequestFactory__OriginationFeePaymentFailed();
        /** TRANSFER TO LEND REQUEST CONTRACT */
        (bool success, ) = payable(lendRequest).call{value: depositMinusFee}(
            ""
        );
        if (!success)
            revert LendRequestFactory__TransferFailed(
                address(lendRequest),
                depositMinusFee
            );
    }

    function _rawAddLiquidity(
        address _lender,
        uint256 _deposit,
        address payable _lendRequest
    ) private {
        /** EFFECTS */
        uint256 originationFee = protocolManager
            .calculateAmountMinus_OriginationFee(_deposit);
        uint256 depositMinusFee = _deposit - originationFee;
        LoanConfigLibrary.RequestState _state = LoanConfigLibrary
            .RequestState
            .OPEN;

        /** UPDATE MAPPING/ LEND REQUEST STATE */
        lenderToTotalAmountRequested[_lender] += _deposit;
        LendRequest_v1(_lendRequest).updateRequestState(_state);

        /** EMIT EVENT */
        emit LendRequestUpdated(_lendRequest, _deposit);

        /** COLLECT ORIGINATION FEE */
        (bool feePaid, ) = payable(protocolManager.FEE_CONTRACT()).call{
            value: originationFee
        }("");
        if (!feePaid) revert LendRequestFactory__OriginationFeePaymentFailed();

        /** TRANSFER TO LEND REQUEST CONTRACT */
        (bool success, ) = payable(_lendRequest).call{value: depositMinusFee}(
            ""
        );
        if (!success)
            revert LendRequestFactory__TransferFailed(
                address(_lendRequest),
                depositMinusFee
            );
    }

    function _rawCancelRequest(
        address _lender,
        address payable _lendRequest,
        uint256 _deposit
    ) private {
        /** EFFECTS */
        uint256 cancellationFee = protocolManager.calculateCancellationFee(
            _deposit
        );
        uint256 amountMinusFee = _deposit - cancellationFee;

        /** UPDATE MAPPINGS */
        s_isValidContract[_lendRequest] = false;
        lenderToTotalAmountRequested[_lender] -= _deposit;
        if (s_loanIsPrioritized[_lendRequest]) {
            s_loanIsPrioritized[_lendRequest] = false;
        }
        /** RESET STATE */
        LendRequest_v1(_lendRequest).resetRequestDetails();

        /** EMIT EVENT */
        emit LendRequestCancelled(_lender, _lendRequest, _deposit);

        /** INTERACTIONS */

        /** COLLECT CANCELLATION FEE */
        (bool feePaid, ) = payable(protocolManager.FEE_CONTRACT()).call{
            value: cancellationFee
        }("");
        if (!feePaid) revert LendRequestFactory__CancellationFeePaymentFailed();
        /** LENDER WITHDRAW FUNDS */
        (bool success, ) = _lender.call{value: amountMinusFee}("");
        if (!success)
            revert LendRequestFactory__LendRequestCancellationFailed(
                _lendRequest.balance
            );
    }

    /*//////////////////////////////////////////////////////////////
             INTERNAL, PUBLIC & PRIVATE  VIEW FUNCTIONS 
    //////////////////////////////////////////////////////////////*/

    function _getTotalActiveLendRequestContractAddresses()
        private
        view
        returns (address[] memory)
    {
       payable address[] memory  lendRequest = new address[](
            s_totalUnPrioritizedLendRequest.length
        );
        uint256 counter = 0;

        for (uint256 i = 0; i < s_totalUnPrioritizedLendRequest.length; i++) {
            LendRequest_v1 lendRequest_v1 = LendRequest_v1(
                payable(address(s_totalUnPrioritizedLendRequest[i]))
            );
           (
            ,
            address _lender,
            LoanConfigLibrary.RequestState _state,

        ) = _getLendRequestDetails(address(lendRequest_v1));
           if (_state != LoanConfigLibrary.RequestState.OPEN)
            revert LendRequestFactory__RequestNotOpen();
            lendRequest[counter] = address(s_totalUnPrioritizedLendRequest[i]);
            counter++;
        }

        address[] memory activeLendRequest = new address[](counter);
        for (uint256 i = 0; i < counter; i++) {
            activeLendRequest[i] = lendRequest[i];
        }

        return activeLendRequest;
    }

    function _getLendRequestDetails(
        address payable  lendRequest
    )
        private
        view
        returns (
            uint256 deposit,
            address lender,
            LoanConfigLibrary.RequestState state,
            uint256 timeCreated
        )
    {
        (deposit, lender, state, timeCreated) = LendRequest_v1(lendRequest)
            .getLendRequestDetails();

        return (deposit, lender, state, timeCreated);
    }
}
