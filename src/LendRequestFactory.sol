// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

//  debug @audit
import {Script, console} from "forge-std/Script.sol";

/*//////////////////////////////////////////////////////////////
                                 IMPORT
    //////////////////////////////////////////////////////////////*/

import {LendRequest} from "./LendRequest.sol";
import {IProtocolManager} from "./interfaces/IProtocolManager.sol";
import {LoanConfigLibrary} from "./libraries/LoanConfigLibrary.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract LendRequestFactory is
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error LendRequestFactory__TransferFailed(
        address lendRequest,
        uint256 amountDeposited
    );
    error LendRequestFactory__LendRequestFailed(uint256 amountDeposited);
    error LendRequestFactory__NoAmountSent();
    error LendRequestFactory__InsufficientBalance(
        uint256 balance,
        uint256 amountDeposited
    );
    error LendRequestFactory__BelowMinimumDeposit();
    error LendRequestFactory__RequestNotOpen();
    error LendRequestFactory__inValidRequest();
    error LendRequestFactory__InsufficientLiquidityProvided();
    error LendRequestFactory__notOwner();
    error LendRequestFactory__CancellationFeePaymentFailed();
    error LendRequestFactory__OriginationFeePaymentFailed();
    error LendRequestFactory__PriorityFeePaymentFailed();
    error LendRequestFactory__LendRequestCancellationFailed(
        uint256 lendRequestContractBalance
    );
    error LendRequestFactory__insufficientPriorityFee();
    error LendRequestFactory__RequestIsPrioritized();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant LIMIT_MARKET = keccak256("LIMIT_MARKET");

    bytes32 public constant LIMIT_MARKET_ADMIN =
        keccak256("TOKEN_MANAGER_ADMIN");

    IProtocolManager private protocolManager;

    LendRequest[] private s_totalNonPrioritizedLendRequest;

    LendRequest[] private s_prioritizedLendRequests;

    mapping(address loanRequest => bool prioritized)
        private s_loanIsPrioritized;

    mapping(address prioritizedLendRequest => address lender)
        private prioritizedLendRequestToLender;

    mapping(address lendRequest => address lender) private lendRequestToLender;

    mapping(address lender => address[] prioritizedLendRequest)
        private userToPrioritizedLendRequestAddresses;

    mapping(address lender => address[] nonPrioritizedLendRequest)
        private userToNonPrioritizedLendRequestAddresses;

    mapping(address lendRequest => bool isValid) private s_isValidContract;

    mapping(address lender => uint256 totalAmountRequested)
        private lenderToTotalAmountDeposited;

    mapping(address prioritizedLendRequest => uint256 position)
        private lendRequestToPositionOnPrioritizedList;

    mapping(address nonPrioritizedLendRequest => uint256 position)
        private lendRequestToPositionOnNonPrioritizedList;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event LendRequestCreated(
        address indexed user,
        address indexed borrowRequestAddress,
        uint256 indexed deposit,
        uint256 originationFee
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
    event LendRequestPrioritized(
        address indexed lendRequestAddress,
        uint256 indexed priorityFee
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _protocolManager) public initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        protocolManager = IProtocolManager(_protocolManager);

        bool roleGranted = _grantRole(
            LIMIT_MARKET_ADMIN,
            IProtocolManager(_protocolManager).LIMIT_MARKET_CONTRACT_ADDRESS()
        );
        if (!roleGranted) revert();
    }
    function _authorizeUpgrade(
        address
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    function getNonPrioritizedRequestViaIndex(
        uint256 index
    ) external view returns (address request) {
        return address(s_totalNonPrioritizedLendRequest[index]);
    }
    function getPrioritizedRequestViaIndex(
        uint256 index
    ) external view returns (address request) {
        return address(s_prioritizedLendRequests[index]);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createRequest(
        address lender,
        bool priority
    ) external payable onlyRole(LIMIT_MARKET_ADMIN) nonReentrant {
        /** CHECKS */

        if (msg.value == 0) revert LendRequestFactory__NoAmountSent();

        if (msg.value > lender.balance)
            revert LendRequestFactory__InsufficientBalance(
                lender.balance,
                msg.value
            );

        if (msg.value < protocolManager.minimumDeposit())
            revert LendRequestFactory__BelowMinimumDeposit();

        _rawCreateRequest(lender, priority);
    }

    function prioritizeLoanRequest(
        address lender,
        address payable lendRequest
    ) external payable onlyRole(LIMIT_MARKET_ADMIN) nonReentrant {
        // check enough fee is sent
        if (
            msg.value <
            protocolManager.calculate_PriorityFee(lendRequest.balance)
        ) revert();

        if (msg.value == 0)
            revert LendRequestFactory__insufficientPriorityFee();
        if (
            msg.value !=
            protocolManager.calculate_PriorityFee(lendRequest.balance)
        ) revert();
        // check if loan request is valid
        if (s_isValidContract[lendRequest] == false)
            revert LendRequestFactory__inValidRequest();
        // check if request is prioritized
        if (s_loanIsPrioritized[lendRequest] == true)
            revert LendRequestFactory__RequestIsPrioritized();
        //get loan details
        (
            address _lender,
            LoanConfigLibrary.RequestState _state,

        ) = _getRequestDetails(lendRequest);

        // check if loan is open
        if (_state != LoanConfigLibrary.RequestState.OPEN)
            revert LendRequestFactory__RequestNotOpen();

        _state = LoanConfigLibrary.RequestState.PRIORITIZING;
        // update state
        LendRequest((lendRequest)).updateRequestState(uint8(_state));

        // check if lender is authorized to interact with loan
        if (
            lendRequestToLender[lendRequest] != address(_lender) ||
            (prioritizedLendRequestToLender[lendRequest] != address(_lender) &&
                address(lender) != address(_lender))
        ) {
            revert LendRequestFactory__notOwner();
        } else {
            _rawPrioritizeLoanRequest(lendRequest, lender);
        }
    }

    function addLiquidity(
        address lender,
        address payable lendRequest
    ) external payable onlyRole(LIMIT_MARKET_ADMIN) nonReentrant {
        if (msg.value == 0)
            revert LendRequestFactory__InsufficientLiquidityProvided();
        if (msg.value > lender.balance)
            revert LendRequestFactory__InsufficientBalance(
                lender.balance,
                msg.value
            );

        // check if loan request is valid
        if (s_isValidContract[lendRequest] == false)
            revert LendRequestFactory__inValidRequest();
        //get loan details
        (
            address _lender,
            LoanConfigLibrary.RequestState _state,

        ) = _getRequestDetails(lendRequest);
        // check if loan is open @audit change to modifier
        if (_state != LoanConfigLibrary.RequestState.OPEN)
            revert LendRequestFactory__RequestNotOpen();
        _state = LoanConfigLibrary.RequestState.ADDING_LIQUIDITY;
        LendRequest(lendRequest).updateRequestState(uint8(_state));

        // check if lender is authorized to interact with loan
        if (
            lendRequestToLender[lendRequest] != address(lender) ||
            prioritizedLendRequestToLender[lendRequest] != address(lender) ||
            address(lender) != address(_lender)
        ) {
            revert LendRequestFactory__notOwner();
        } else {
            _rawAddLiquidity(lender, lendRequest);
        }
    }

    function cancelRequest(
        address lender,
        address payable lendRequest
    ) external payable onlyRole(LIMIT_MARKET_ADMIN) nonReentrant {
        // check if loan request is valid'
        if (s_isValidContract[lendRequest] == false)
            revert LendRequestFactory__inValidRequest();
        uint256 contractBalance;
        //get loan details
        (
            address _lender,
            LoanConfigLibrary.RequestState _state,

        ) = _getRequestDetails(lendRequest);
        // check if loan is open
        if (_state != LoanConfigLibrary.RequestState.OPEN)
            revert LendRequestFactory__RequestNotOpen();

        // check if lender is authorized to interact with loan
        if (
            lendRequestToLender[lendRequest] != address(_lender) ||
            (prioritizedLendRequestToLender[lendRequest] != address(_lender) &&
                address(lender) != address(_lender))
        ) {
            revert LendRequestFactory__notOwner();
        } else {
            contractBalance = lendRequest.balance;
            _state = LoanConfigLibrary.RequestState.CANCELLING;
            LendRequest(lendRequest).updateRequestState(uint8(_state));
            _rawCancelRequest(lender, lendRequest, contractBalance);
        }
    }

    /*//////////////////////////////////////////////////////////////
                    EXTERNAL  VIEW FUNCTIONS 
    //////////////////////////////////////////////////////////////*/

    // function getTotalActivePrioritizedLendRequests(
    //     uint256 _batchLimit,
    //     uint256 numOfResponse
    // ) external view returns (address[] memory) {
    //     uint256 total = s_prioritizedLendRequests.length;
    //     uint256 limit = total > _batchLimit ? _batchLimit : total;
    //     address[] memory lendRequest = new address[](
    //         s_prioritizedLendRequests.length
    //     );
    //     uint256 counter = 0;

    //     for (uint256 i = 0; i < limit; i++) {
    //         LendRequest LendRequest = LendRequest(
    //             payable(address(s_prioritizedLendRequests[i]))
    //         );
    //         uint8 status = _getLendRequestDetails(address(LendRequest));
    //         if (status != 0) {
    //             continue;
    //         }
    //         lendRequest[counter] = address(s_prioritizedLendRequests[i]);
    //         if (lendRequest.length == numOfResponse) {
    //             break;
    //         }
    //         counter++;//check
    //     }

    //     address[] memory activePrioritizedLendRequests = new address[](counter);
    //     for (uint256 i = 0; i < counter; i++) {
    //         activePrioritizedLendRequests[i] = lendRequest[i];
    //     }
    //     return activePrioritizedLendRequests;
    // }

    // function getBatchedActiveLendRequestAddresses(
    //     uint256 startIndex,
    //     uint256 numberOfResponse,
    //     uint256 _batchLimit
    // ) external view returns (address[] memory) {
    //     uint256 total = _getTotalActiveLendRequestContractAddresses().length;
    //     uint256 _startIndex = startIndex > total ? 0 : startIndex;
    //     uint256 limit = total > _batchLimit ? _batchLimit : total;
    //     uint256 _numberOfResponse = numberOfResponse > limit
    //         ? limit
    //         : numberOfResponse;
    //     address[]
    //         memory activeLendRequests = _getTotalActiveLendRequestContractAddresses();
    //     address[] memory batchedLendRequests = new address[](_numberOfResponse);

    //     for (uint256 i = _startIndex; i < _numberOfResponse; i++) {
    //         if (i < startIndex) {
    //             continue;
    //         }
    //         batchedLendRequests[i] = activeLendRequests[i];

    //         if (i > limit) {
    //             break;
    //         }
    //     }
    //     return batchedLendRequests;
    // }

    // function getTotalActiveLendRequestAddress()
    //     external
    //     view
    //     returns (uint256 numberOfResponse)
    // {
    //     return _getTotalActiveLendRequestContractAddresses().length;
    // }

    // function getLendRequestPositionOnActiveRequestQue(
    //     address lendRequest
    // ) external view returns (uint256 position) {
    //     if (s_isValidContract[lendRequest] == false)
    //         revert LendRequestFactory__InValidContractAddress();
    //     address[]
    //         memory lendRequests = _getTotalActiveLendRequestContractAddresses();
    //     for (uint256 i = 0; i < lendRequests.length; i++) {
    //         if (lendRequests[i] == address(lendRequest)) {
    //             position = i + 1;
    //         }
    //     }
    //     return position;
    // }

    // function getTotalActiveLendRequestContractCount()
    //     external
    //     view
    //     returns (uint256 numberOfContracts)
    // {
    //     return _getTotalActiveLendRequestContractAddresses().length;
    // }

    // function getUserToLendRequestAddresses(
    //     address user
    // )
    //     external
    //     view
    //     returns (
    //         address[] memory lendRequestAddresses,
    //         address[] memory prioritizedLendRequestContracts
    //     )
    // {
    //     return (
    //         userToLendRequestAddresses[user],
    //         userToPrioritizedLendRequestAddresses[user]
    //     );
    // }

    // function getPrioritizedLendRequest(
    //     address LendRequestContractAddress
    // ) external view returns (bool isPrioritized) {
    //     return s_loanIsPrioritized[LendRequestContractAddress];
    // }

    /*//////////////////////////////////////////////////////////////
                 PUBLIC, PRIVATE AND INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _rawCreateRequest(address _lender, bool _priority) private {
        /** EFFECTS */
        uint256 depositMinusFee;
        uint256 originationFee = protocolManager.calculate_OriginationFee(
            msg.value
        );
        uint256 priorityFee = protocolManager.calculate_PriorityFee(msg.value);
        if (_priority == true) {
            depositMinusFee = msg.value - (originationFee + priorityFee);
        } else {
            depositMinusFee = msg.value - originationFee;
        }
        /** DEPLOY NEW LEND REQUEST CONTRACT */
        LendRequest lendRequest;
        try
            new LendRequest{value: depositMinusFee}(
                _lender,
                block.timestamp,
                address(protocolManager)
            )
        returns (LendRequest _lendRequest) {
            lendRequest = _lendRequest;
            if (_priority == true) {
                s_loanIsPrioritized[address(lendRequest)] = true;
                prioritizedLendRequestToLender[address(lendRequest)] = address(
                    _lender
                );
                s_prioritizedLendRequests.push(lendRequest);
                userToPrioritizedLendRequestAddresses[_lender].push(
                    address(lendRequest)
                );
                lendRequestToPositionOnPrioritizedList[address(lendRequest)] =
                    s_prioritizedLendRequests.length +
                    protocolManager.INDEX_PRECISION();
            } else {
                s_totalNonPrioritizedLendRequest.push(lendRequest);
                userToNonPrioritizedLendRequestAddresses[_lender].push(
                    address(lendRequest)
                );
                lendRequestToPositionOnNonPrioritizedList[
                    address(lendRequest)
                ] =
                    s_totalNonPrioritizedLendRequest.length +
                    protocolManager.INDEX_PRECISION();
            }
        } catch {
            revert LendRequestFactory__LendRequestFailed(depositMinusFee);
        }

        lendRequestToLender[address(lendRequest)] = address(_lender);
        lenderToTotalAmountDeposited[_lender] += msg.value;
        s_isValidContract[address(lendRequest)] = true;

        /** EMIT EVENTS */
        emit LendRequestCreated(
            _lender,
            address(lendRequest),
            msg.value,
            originationFee
        );
        if (_priority == true)
            emit LendRequestPrioritized(address(lendRequest), priorityFee);

        /** INTERACTIONS */

        if (_priority == true) {
            /** SUM BOTH PRIORITY AND ORIGINATION FEES TOGETHER */
            uint256 fee = priorityFee + originationFee;
            /** COLLECT PRIORITY FEE */
            (bool priorityFeePaid, ) = protocolManager.FEE_CONTRACT().call{
                value: fee
            }("");
            if (!priorityFeePaid)
                revert LendRequestFactory__PriorityFeePaymentFailed();
        } else {
            /** COLLECT ORIGINATION FEE */
            (bool originationFeePaid, ) = protocolManager.FEE_CONTRACT().call{
                value: originationFee
            }("");
            if (!originationFeePaid)
                revert LendRequestFactory__OriginationFeePaymentFailed();
        }
    }

    function _rawPrioritizeLoanRequest(
        address payable _lendRequest,
        address _lender
    ) private {
        uint256 precision = protocolManager.INDEX_PRECISION();

        // nullify mapping

        delete userToNonPrioritizedLendRequestAddresses[_lender][
            lendRequestToPositionOnNonPrioritizedList[_lendRequest]
        ]; //@audit array check
        delete s_totalNonPrioritizedLendRequest[
            lendRequestToPositionOnNonPrioritizedList[_lendRequest]
        ];

        // delete mapping
        delete lendRequestToPositionOnNonPrioritizedList[_lendRequest];

        // set prioritized mappings
        s_loanIsPrioritized[address(_lendRequest)] = true;
        prioritizedLendRequestToLender[_lendRequest] = address(_lender);
        s_prioritizedLendRequests.push(LendRequest(_lendRequest));
        userToPrioritizedLendRequestAddresses[_lender].push(
            address(_lendRequest)
        );
        lendRequestToPositionOnPrioritizedList[_lendRequest] =
            s_prioritizedLendRequests.length +
            precision;

        LoanConfigLibrary.RequestState state = LoanConfigLibrary
            .RequestState
            .OPEN;
        emit LendRequestPrioritized(_lendRequest, msg.value);

        /** COLLECT PRIORITY FEE */
        (bool priorityFeePaid, ) = address(protocolManager.FEE_CONTRACT()).call{
            value: msg.value
        }("");
        if (!priorityFeePaid)
            revert LendRequestFactory__PriorityFeePaymentFailed();

        LendRequest(_lendRequest).updateRequestState(uint8(state));
    }

    function _rawAddLiquidity(
        address _lender,
        address payable _lendRequest
    ) private {
        /** EFFECTS */
        uint256 originationFee = protocolManager.calculate_OriginationFee(
            msg.value
        );
        uint256 depositMinusFee = msg.value - originationFee;
        if (depositMinusFee + originationFee != msg.value) revert();

        uint8 _state = uint8(LoanConfigLibrary.RequestState.OPEN);

        /** UPDATE MAPPING */
        lenderToTotalAmountDeposited[_lender] += msg.value;

        /** EMIT EVENT */
        emit LendRequestUpdated(_lendRequest, msg.value);

        /** TRANSFER TO LEND REQUEST CONTRACT */
        (bool success, ) = _lendRequest.call{value: depositMinusFee}("");

        if (!success)
            revert LendRequestFactory__TransferFailed(
                address(_lendRequest),
                depositMinusFee
            );

        /** COLLECT ORIGINATION FEE */
        (bool feePaid, ) = protocolManager.FEE_CONTRACT().call{
            value: originationFee
        }("");

        if (!feePaid) revert LendRequestFactory__OriginationFeePaymentFailed();

        /** UPDATE LEND REQUEST STATE */
        LendRequest(_lendRequest).updateRequestState(_state);
    }

    function _rawCancelRequest(
        address _lender,
        address payable _lendRequest,
        uint256 contractBalance
    ) private {
        /** EFFECTS */
        uint256 cancellationFee = protocolManager.calculateCancellationFee(
            _lendRequest.balance
        );

        uint256 amountMinusFee = contractBalance - cancellationFee;

        /** UPDATE MAPPINGS */
        s_isValidContract[_lendRequest] = false;
        lenderToTotalAmountDeposited[_lender] -= contractBalance;
        if (s_loanIsPrioritized[_lendRequest]) {
            s_loanIsPrioritized[_lendRequest] = false;
        }

        /** EMIT EVENT */
        emit LendRequestCancelled(
            _lender,
            _lendRequest,
            contractBalance,
            address(_lendRequest).balance
        );

        /** INTERACTIONS */

        /** COLLECT CANCELLATION FEE */
        (bool feePaid, ) = protocolManager.FEE_CONTRACT().call{
            value: cancellationFee
        }("");
        if (!feePaid) revert LendRequestFactory__CancellationFeePaymentFailed();
        /** LENDER WITHDRAW FUNDS */
        (bool success, ) = _lender.call{value: amountMinusFee}("");
        if (!success)
            revert LendRequestFactory__LendRequestCancellationFailed(
                address(_lendRequest).balance
            );
        /** RESET STATE */
        LendRequest(_lendRequest).resetRequestDetails();
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL VIEW FUNCTIONS 
    //////////////////////////////////////////////////////////////*/

    function getTotalRequests()
        external
        view
        returns (
            uint256 totalNonPrioritizedLendRequests,
            uint256 totalPrioritizedLendRequest
        )
    {
        return (
            s_totalNonPrioritizedLendRequest.length,
            s_prioritizedLendRequests.length
        );
    }

    /*//////////////////////////////////////////////////////////////
             INTERNAL, PUBLIC & PRIVATE  VIEW FUNCTIONS 
    //////////////////////////////////////////////////////////////*/

    // function _getTotalActiveLendRequestContractAddresses()
    //     private
    //     view
    //     returns ()
    // {
    // address[] memory  lendRequest = new address[](
    //     s_totalNonPrioritizedLendRequest.length
    // );
    // uint256 counter = 0;

    // for (uint256 i = 0; i < s_totalNonPrioritizedLendRequest.length; i++) {
    //     LendRequest LendRequest = LendRequest(
    //         (address(s_totalNonPrioritizedLendRequest[i]))
    //     );
    //    (
    //     ,
    //     address _lender,
    //     LoanConfigLibrary.RequestState _state,

    // ) = _getRequestDetails(address(LendRequest));
    //    if (_state != LoanConfigLibrary.RequestState.OPEN)
    //     revert LendRequestFactory__RequestNotOpen();
    //     lendRequest[counter] = address(s_totalNonPrioritizedLendRequest[i]);
    //     counter++;
    // }

    // address[] memory activeLendRequest = new address[](counter);
    // for (uint256 i = 0; i < counter; i++) {
    //     activeLendRequest[i] = lendRequest[i];
    // }

    // return activeLendRequest;
    // }

    function _getRequestDetails(
        address payable lendRequest
    )
        private
        view
        returns (
            address lender,
            LoanConfigLibrary.RequestState state,
            uint256 timeCreated
        )
    {
        (lender, state, timeCreated) = LendRequest(lendRequest)
            .getRequestDetails();

        return (lender, state, timeCreated);
    }
}
