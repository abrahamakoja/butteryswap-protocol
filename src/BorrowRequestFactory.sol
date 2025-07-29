// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title BorrowRequestFactory
/// @author ButterySwap Protocol
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details

//  debug
import {Script, console} from "forge-std/Script.sol";

/*//////////////////////////////////////////////////////////////
                                 IMPORT
    //////////////////////////////////////////////////////////////*/

import {BorrowRequest} from "./BorrowRequest.sol";
import {erc20TokenLibrary} from "./libraries/erc20TokenLibrary.sol";
import {IProtocolManager} from "./interfaces/IProtocolManager.sol";
import {ITokenManager} from "./interfaces/ITokenManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {LoanConfigLibrary} from "./libraries/LoanConfigLibrary.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract BorrowRequestFactory is Ownable, ReentrancyGuard {
    //@audit ensure states are updated after updates creation and deletion and always emit after state change
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error BorrowRequestFactory__InvalidTokenCount(uint256 tokenCount);
    error BorrowRequestFactory__unSupportedToken(address token);
    error BorrowRequestFactory__NoCollateralSent(uint256 collateralAmount);
    error BorrowRequestFactory__inValidContractAddress();
    error BorrowRequestFactory__InvalidRequest();
    error BorrowRequestFactory__insufficientPriorityFee();
    error BorrowRequestFactory__TransferFailed();
    error BorrowRequestFactory__collateralAssetMaxLimitReached();
    error BorrowRequestFactory__providedAssetsOutOfRange(
        uint256 MAX_ASSET_LIMIT,
        uint256 numberOfAssetsProvided
    );
    error BorrowRequestFactory__rangeDataMisMatch();
    error BorrowRequestFactory__notOwner();
    error BorrowRequestFactory__InsufficientFunds(
        uint256 borrowRequestBalance,
        uint256 collateralAmount
    );
    error BorrowRequestFactory__RequestNotOpen();
    error BorrowRequestFactory__UnAuthorized();
    error BorrowRequestFactory__BorrowRequestFailed();
    error BorrowRequestFactory__PriorityFeePaymentFailed();
    error BorrowRequestFactory__OriginationFeePaymentFailed();
    error LendRequestFactory__insufficientFeeAmount();
    error BorrowRequestFactory__collateralValueMismatch();
    error BorrowRequestFactory__RequestIsPrioritized();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    //@audit check all mapping
    IProtocolManager private immutable protocolManager;

    BorrowRequest[] private totalBorrowRequests;

    BorrowRequest[] private s_prioritizedBorrowRequests;

    
    mapping(address borrower => address[] borrowRequestAddresses)
        private userToBorrowRequestAddresses;

    mapping(address borrowRequest => address borrower)
        private borrowRequestToBorrower;

    mapping(address borrower => address[] prioritizedBorrowRequests)
        private userToPrioritizedBorrowRequestAddresses;

    mapping(address prioritizedBorrowRequest => address borrower)
        private prioritizedBorrowRequestToBorrower;

    mapping(address loanRequest => bool prioritized)
        private s_loanIsPrioritized;

    mapping(address => bool) private s_isValidContract;

    mapping(address borrowRequest => mapping(address collateral => uint256 value))
        private collateralToValue;

    mapping(address borrower => uint256 totalAmountRequested)
        private borrowerToTotalAmountRequested;

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

    event BorrowRequestCreated(
        address indexed user,
        address indexed borrowRequestAddress,
        uint256 indexed totalCollateralValue
    );
    event BorrowRequestCancelled(
        address indexed borrower,
        address indexed borrowRequestAddress,
        uint256 indexed totalCollateralValue,
        uint256 borrowRequestBalance
    );
    event BorrowRequestPrioritized(address indexed borrowRequestAddress);
    event BorrowRequestUpdated(
        address indexed borrowRequestAddress,
        uint256 indexed depositedAmount,
        uint256 indexed amountRequested
    );
    event BorrowRequestPrioritized(
        address indexed borrowRequestAddress,
        uint256 indexed priorityFee
    );

    /** CONSTRUCTOR */
    constructor(address _protocolManager) Ownable(msg.sender) {
        protocolManager = IProtocolManager(_protocolManager);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new BorrowRequest instance
    /// @param collateralAmount The amount of collateral to be locked
    /// @param tokens The list of tokens to be used as collateral
    /// @param borrower The address of the enforcer contract
    /// @param priority The address of the enforcer contract
    function createRequest(
        uint256[] calldata collateralAmount,
        uint256 loanAmountRequested,
        address[] calldata tokens,
        address borrower,
        bool priority
    ) external payable onlyLimitMarket nonReentrant {
        // @note check health factor of each token
        // @audit if value of tokens match requested collateral amount based of ltv

        /** CHECKS */
        // uint256 totalCollateralValue; //@audit change this to a helper function that gets value in eth for tokens

        if (collateralAmount.length != tokens.length)
            revert BorrowRequestFactory__rangeDataMisMatch();

        if (
            tokens.length == 0 ||
            tokens.length > protocolManager.MAX_ASSET_LIMIT()
        ) revert BorrowRequestFactory__InvalidTokenCount(tokens.length);

        _rawCreateRequest(
            collateralAmount,
            loanAmountRequested,
            tokens,
            borrower,
            priority
        );
    }

    function prioritizeLoanRequest(
        address borrower,
        address borrowRequest
    ) external payable onlyLimitMarket nonReentrant {
        if (
            msg.value <
            protocolManager.calculate_PriorityFee(borrowRequest.balance)
        ) revert();

        if (msg.value == 0)
            revert BorrowRequestFactory__insufficientPriorityFee();
        if (
            msg.value !=
            protocolManager.calculate_PriorityFee(borrowRequest.balance)
        ) revert();

        if (s_isValidContract[borrowRequest] == false)
            revert BorrowRequestFactory__InvalidRequest();

        if (s_loanIsPrioritized[borrowRequest] == true)
            revert BorrowRequestFactory__RequestIsPrioritized();

        /** GET LOAN DETAILS */
        (
            ,
            ,
            ,
            address _borrower,
            LoanConfigLibrary.RequestState _state,

        ) = _getRequestDetails(borrowRequest);

        if (_state != LoanConfigLibrary.RequestState.OPEN)
            revert BorrowRequestFactory__RequestNotOpen();

        _state = LoanConfigLibrary.RequestState.PRIORITIZING;

        BorrowRequest(borrowRequest).updateRequestState(_state);

        // check borrower owns borrow request
        if (
            borrowRequestToBorrower[borrowRequest] != address(_borrower) ||
            (prioritizedBorrowRequestToBorrower[borrowRequest] !=
                address(_borrower) &&
                address(borrower) != address(_borrower))
        ) revert BorrowRequestFactory__notOwner();

        _rawPrioritizeLoanRequest(borrowRequest, borrower, _state);
    }

    function addLiquidity(
        address borrower,
        address borrowRequest,
        address[] calldata tokens,
        uint256[] calldata collateralAmounts,
        uint256 loanAmountRequested
    ) external payable onlyLimitMarket nonReentrant {
        // @audit if value of tokens match requested collateral amount based of ltv
        // check borrowRequest is valid
        if (s_isValidContract[borrowRequest] == false)
            revert BorrowRequestFactory__InvalidRequest();
        /** GET LOAN DETAILS */
        (
            address[] memory _tokens,
            ,
            ,
            address _borrower,
            LoanConfigLibrary.RequestState _state,

        ) = _getRequestDetails(borrowRequest);

        if (_state != LoanConfigLibrary.RequestState.OPEN)
            revert BorrowRequestFactory__RequestNotOpen();
        _state = LoanConfigLibrary.RequestState.ADDING_LIQUIDITY;
        BorrowRequest(borrowRequest).updateRequestState(_state);

        // check collateralAmount and tokens match in length
        if (collateralAmounts.length != tokens.length) {
            revert BorrowRequestFactory__rangeDataMisMatch();
        }

        // check borrower owns borrow request
        if (
            borrowRequestToBorrower[borrowRequest] != address(_borrower) ||
            (prioritizedBorrowRequestToBorrower[borrowRequest] !=
                address(_borrower) &&
                address(borrower) != address(_borrower))
        ) revert BorrowRequestFactory__notOwner();

        //   check already deposited tokens count is below or equal to max asset limit allowed
        if (!(_tokens.length <= protocolManager.MAX_ASSET_LIMIT())) {
            revert BorrowRequestFactory__collateralAssetMaxLimitReached();
        }

        // check if new token length exceeds available slot
        if (
            tokens.length > (protocolManager.MAX_ASSET_LIMIT() - _tokens.length)
        ) {
            revert BorrowRequestFactory__providedAssetsOutOfRange(
                protocolManager.MAX_ASSET_LIMIT(),
                tokens.length
            );
        }

        _rawAddLiquidity(
            borrower,
            borrowRequest,
            loanAmountRequested,
            tokens,
            collateralAmounts,
            _state
        );
    }

    function cancelRequest(
        address borrower,
        address borrowRequest
    ) external payable onlyLimitMarket nonReentrant {
        if (s_isValidContract[borrowRequest] == false)
            revert BorrowRequestFactory__InvalidRequest();
        /** GET LOAN DETAILS */
        (
            address[] memory _tokens,
            uint256[] memory _collateralAmount,
            ,
            address _borrower,
            LoanConfigLibrary.RequestState _state,

        ) = _getRequestDetails(borrowRequest);

        /** CHECKS */

        if (_state != LoanConfigLibrary.RequestState.OPEN)
            revert BorrowRequestFactory__RequestNotOpen();
        _state = LoanConfigLibrary.RequestState.CANCELLING;
        BorrowRequest(borrowRequest).updateRequestState(_state);

        // check borrowRequest is valid
        if (s_isValidContract[borrowRequest] == false)
            revert BorrowRequestFactory__InvalidRequest();

        // check borrower owns borrow request
        if (
            borrowRequestToBorrower[borrowRequest] != address(_borrower) ||
            (prioritizedBorrowRequestToBorrower[borrowRequest] !=
                address(_borrower) &&
                address(borrower) != address(_borrower))
        ) revert BorrowRequestFactory__notOwner();

        _rawCancelRequest(
            borrower,
            borrowRequest,
            _tokens,
            _collateralAmount,
            _state
        );
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    // Function to retrieve all borrow request contracts for a user // legacy
    // function getUserToBorrowRequestAddresses(
    //     address user
    // )
    //     external
    //     view
    //     returns (
    //         address[] memory borrowRequestAddresses,
    //         address[] memory prioritizedBorrowRequestAddresses
    //     )
    // {
    //     return (
    //         userToBorrowRequestAddresses[user],
    //         userToPrioritizedBorrowRequestAddresses[user]
    //     );
    // }

    // function getTotalActivePrioritizedBorrowRequests(
    //     uint256 _batchLimit,
    //     uint256 numOfResponse
    // ) external view returns (address[] memory) {
    //     uint256 total = s_prioritizedBorrowRequests.length;
    //     uint256 limit = total > _batchLimit ? _batchLimit : total;
    //     address[] memory borrowRequest = new address[](
    //         s_prioritizedBorrowRequests.length
    //     );
    //     uint256 counter = 0;

    //     for (uint256 i = 0; i < limit; i++) {
    //         BorrowRequest BorrowRequest = BorrowRequest(
    //             payable(address(s_prioritizedBorrowRequests[i]))
    //         );
    //         uint8 status = uint8(BorrowRequest.getRequestState());
    //         if (status != 0) {
    //             continue;
    //         }
    //         borrowRequest[counter] = address(s_prioritizedBorrowRequests[i]);
    //         if (borrowRequest.length == numOfResponse) {
    //             break;
    //         }
    //         counter++;
    //     }

    //     address[] memory activePrioritizedBorrowRequests = new address[](
    //         counter
    //     );
    //     for (uint256 i = 0; i < counter; i++) {
    //         activePrioritizedBorrowRequests[i] = borrowRequest[i];
    //     }
    //     return activePrioritizedBorrowRequests;
    // }

    // function getBatchedActiveBorrowRequestContractAddresses(
    //     uint256 startIndex,
    //     uint256 numberOfResponse,
    //     uint256 _batchLimit
    // ) external view returns (address[] memory) {
    //     uint256 total = _getTotalActiveBorrowRequestContractAddresses().length;
    //     uint256 _startIndex = startIndex > total ? 0 : startIndex;
    //     uint256 limit = total > _batchLimit ? _batchLimit : total;
    //     uint256 _numberOfResponse = numberOfResponse > limit
    //         ? limit
    //         : numberOfResponse;
    //     address[]
    //         memory activeBorrowRequests = _getTotalActiveBorrowRequestContractAddresses();
    //     address[] memory batchedBorrowRequests = new address[](
    //         _numberOfResponse
    //     );

    //     for (uint256 i = _startIndex; i < _numberOfResponse; i++) {
    //         if (i < startIndex) {
    //             continue;
    //         }
    //         batchedBorrowRequests[i] = activeBorrowRequests[i];

    //         if (i > limit) {
    //             break;
    //         }
    //     }
    //     return batchedBorrowRequests;
    // }

    // function getTotalActiveBorrowRequestContractCount()
    //     external
    //     view
    //     returns (uint256 numberOfContracts)
    // {
    //     return _getTotalActiveBorrowRequestContractAddresses().length;
    // }

    // @dev returns the total active borrow requests addresses.
    // function _getTotalActiveBorrowRequestContractAddresses()
    //     private
    //     view
    //     returns (address[] memory)
    // {
    //     address[] memory borrowRequest = new address[](
    //         totalBorrowRequests.length
    //     );
    //     uint256 counter = 0;

    //     for (uint256 i = 0; i < totalBorrowRequests.length; i++) {
    //         BorrowRequest BorrowRequest = BorrowRequest(
    //             payable(address(totalBorrowRequests[i]))
    //         );
    //         uint8 status = uint8(BorrowRequest.getRequestState());
    //         if (status != 0) {
    //             continue;
    //         }
    //         borrowRequest[counter] = address(totalBorrowRequests[i]);
    //         counter++;
    //     }

    //     address[] memory activeBorrowRequest = new address[](counter);
    //     for (uint256 i = 0; i < counter; i++) {
    //         activeBorrowRequest[i] = borrowRequest[i];
    //     }
    //     return activeBorrowRequest;
    // }

    /// @dev returns the specific index of an active borrow requests within the array of active borrow request.
    // function getBorrowRequestPositionOnActiveRequestQue(
    //     address _borrowRequest
    // ) external view returns (uint256 position) {
    //     if (s_isValidContract[_borrowRequest] == false)
    //         revert BorrowRequestFactory__inValidContractAddress();
    //     address[]
    //         memory borrowRequests = _getTotalActiveBorrowRequestContractAddresses();
    //     for (uint256 i = 0; i < borrowRequests.length; i++) {
    //         if (borrowRequests[i] == address(_borrowRequest)) {
    //             position = i + 1;
    //         }
    //     }
    //     return position;
    // }

    // function getPrioritizedBorrowRequest(
    //     address BorrowRequestContractAddress
    // ) external view returns (bool isPrioritized) {
    //     return s_loanIsPrioritized[BorrowRequestContractAddress];
    // }

    /*//////////////////////////////////////////////////////////////
                 PUBLIC, PRIVATE AND INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal function to create a new BorrowRequest instance
    /// @param _collateralAmount The amount of collateral to be locked
    /// @param _tokens The list of tokens to be used as collateral
    /// @param _borrower The address of the enforcer contract
    /// @param _priority The address of the enforcer contract
    function _rawCreateRequest(
        uint256[] calldata _collateralAmount,
        uint256 _loanAmountRequested,
        address[] calldata _tokens,
        address _borrower,
        bool _priority
    ) private {
        /** EFFECTS */
        uint256 totalCollateralValue;
        uint256 originationFee;
        uint256 priorityFee;
        BorrowRequest borrowRequest;
        try
            new BorrowRequest(
                _borrower,
                _collateralAmount,
                _loanAmountRequested,
                _tokens,
                block.timestamp,
                address(protocolManager)
            )
        returns (BorrowRequest _BorrowRequest) {
            borrowRequest = _BorrowRequest;
            for (uint256 index = 0; index < _tokens.length; index++) {
                // check each token is listed
                if (
                    !ITokenManager(protocolManager.TokenManager())
                        .checkIsTokenListed(address(_tokens[index]))
                ) revert BorrowRequestFactory__unSupportedToken(_tokens[index]);

                if (_collateralAmount[index] == 0)
                    revert BorrowRequestFactory__NoCollateralSent(
                        _collateralAmount[index]
                    );
                totalCollateralValue += protocolManager
                    .calculate_CollateralValue(_collateralAmount[index]);

                collateralToValue[address(borrowRequest)][
                    _tokens[index]
                ] += _collateralAmount[index];

                // Reset the allowance to the exact collateralAmount
                erc20TokenLibrary.approveTokens(
                    _tokens[index],
                    address(this),
                    _collateralAmount[index]
                );
            }

            if (_priority) {
                s_loanIsPrioritized[address(borrowRequest)] = true;

                prioritizedBorrowRequestToBorrower[
                    address(borrowRequest)
                ] = address(_borrower);

                s_prioritizedBorrowRequests.push(borrowRequest);

                userToPrioritizedBorrowRequestAddresses[_borrower].push(
                    address(borrowRequest)
                );
            } else {
                totalBorrowRequests.push(borrowRequest);

                borrowRequestToBorrower[address(borrowRequest)] = address(
                    _borrower
                );

                userToBorrowRequestAddresses[_borrower].push(
                    address(borrowRequest)
                );
            }
        } catch {
            revert BorrowRequestFactory__BorrowRequestFailed();
        }

        if (_loanAmountRequested < totalCollateralValue)
            revert BorrowRequestFactory__collateralValueMismatch(); //@audit change to ltv check

        priorityFee = protocolManager.calculate_PriorityFee(
            totalCollateralValue
        );

        originationFee = protocolManager.calculate_OriginationFee(
            totalCollateralValue
        );
        if (msg.value == 0) revert LendRequestFactory__insufficientFeeAmount();
        if (_priority == true && msg.value != (originationFee + priorityFee))
            revert();
        if (_priority == false && msg.value != originationFee) revert();

        borrowerToTotalAmountRequested[_borrower] += totalCollateralValue;

        s_isValidContract[address(borrowRequest)] = true;

        /** EMIT EVENTS */
        emit BorrowRequestCreated(
            _borrower,
            address(borrowRequest),
            totalCollateralValue
        );
        if (_priority == true)
            emit BorrowRequestPrioritized(address(borrowRequest));

        /** INTERACTIONS */

        /** COLLECT PRIORITY FEE */
        if (_priority == true) {
            /** SUM BOTH PRIORITY AND ORIGINATION FEES TOGETHER */
            uint256 fee = priorityFee + originationFee;
            (bool priorityFeePaid, ) = protocolManager.FEE_CONTRACT().call{
                value: fee
            }("");
            if (!priorityFeePaid)
                revert BorrowRequestFactory__PriorityFeePaymentFailed();
        } else {
            /** COLLECT ORIGINATION FEE */
            (bool originationFeePaid, ) = protocolManager.FEE_CONTRACT().call{
                value: originationFee
            }("");
            if (!originationFeePaid)
                revert BorrowRequestFactory__OriginationFeePaymentFailed();
        }

        /** TRANSFER TOKENS TO BORROW REQUEST CONTRACT */
        for (uint256 index = 0; index < _tokens.length; index++) {
            erc20TokenLibrary.transferFromTokens(
                _tokens[index],
                address(_borrower),
                address(borrowRequest),
                _collateralAmount[index]
            );
        }
    }

    function _rawPrioritizeLoanRequest(
        address _borrowRequest,
        address _borrower,
        LoanConfigLibrary.RequestState _state
    ) private {
        /** UPDATE MAPPING */
        delete borrowRequestToBorrower[address(_borrowRequest)];
        s_loanIsPrioritized[address(_borrowRequest)] = true;

        prioritizedBorrowRequestToBorrower[address(_borrowRequest)] = address(
            _borrower
        );

        s_prioritizedBorrowRequests.push(BorrowRequest(_borrowRequest));

        userToPrioritizedBorrowRequestAddresses[_borrower].push(
            address(_borrowRequest)
        );

        _state = LoanConfigLibrary.RequestState.OPEN;
        emit BorrowRequestPrioritized(_borrowRequest, msg.value);

        /** COLLECT PRIORITY FEE */
        (bool priorityFeePaid, ) = address(protocolManager.FEE_CONTRACT()).call{
            value: msg.value
        }("");
        if (!priorityFeePaid)
            revert BorrowRequestFactory__PriorityFeePaymentFailed();

        BorrowRequest(_borrowRequest).updateRequestState(_state);
    }

    function _rawCancelRequest(
        address _borrower,
        address _borrowRequest,
        address[] memory _tokens,
        uint256[] memory _collateralAmount,
        LoanConfigLibrary.RequestState _state
    ) private {
        uint256 cancellationFee;
        uint256 totalCollateralValue; //@audit change this to a helper function that gets value in eth for tokens

        /** EFFECTS */

        for (uint256 index = 0; index < _collateralAmount.length; index++) {
            totalCollateralValue += _collateralAmount[index];
        }
        cancellationFee = protocolManager.calculateCancellationFee(
            totalCollateralValue
        );
        _state = LoanConfigLibrary.RequestState.CANCELLED;

        /**UPDATE MAPPINGS */
        s_isValidContract[_borrowRequest] = false;
        borrowerToTotalAmountRequested[_borrower] -= totalCollateralValue;
        if (s_loanIsPrioritized[_borrowRequest]) {
            s_loanIsPrioritized[_borrowRequest] = false;
        }

        /** EMIT EVENTS */
        emit BorrowRequestCancelled(
            address(_borrower),
            address(_borrowRequest),
            totalCollateralValue,
            address(_borrowRequest).balance
        );

        /** INTERACTIONS */

        /** BORROWER WITHDRAWS ALL COLLATERAL */
        for (uint256 index = 0; index < _tokens.length; index++) {
            erc20TokenLibrary.transferTokens(
                address(_tokens[index]),
                address(_borrower),
                erc20TokenLibrary.getBalance(
                    address(_borrowRequest),
                    address(_tokens[index])
                )
            );
        }

        /** COLLECT CANCELLATION FEE */
        (bool success, ) = protocolManager.FEE_CONTRACT().call{
            value: cancellationFee
        }("");
        if (!success) {
            revert();
        }

        /** UPDATE STATE */
        BorrowRequest(_borrowRequest).updateRequestState(_state); // @audit try resetting
    }

    function _rawAddLiquidity(
        address _borrower,
        address _borrowRequest,
        uint256 _loanAmountRequested,
        address[] memory _tokens,
        uint256[] memory _collateralAmounts,
        LoanConfigLibrary.RequestState _state
    ) private {
        /** EFFECTS */
        uint256 totalCollateralValue;
        uint256 originationFee;

        // check if asset is supported by protocol / approve and execute transfer within the same loop
        for (uint256 index = 0; index > _tokens.length; index++) {
            if (
                ITokenManager(protocolManager.TokenManager())
                    .checkIsTokenListed(address(_tokens[index]))
            ) {
                revert BorrowRequestFactory__unSupportedToken(
                    address(_tokens[index])
                );
            }

            totalCollateralValue += protocolManager.calculate_CollateralValue(
                _collateralAmounts[index]
            );

            /**UPDATE MAPPING */
            borrowerToTotalAmountRequested[_borrower] += _collateralAmounts[
                index
            ];

            collateralToValue[address(_borrowRequest)][
                _tokens[index]
            ] += _collateralAmounts[index];

            // interactions

            //  approve tokens
            erc20TokenLibrary.approveTokens(
                _tokens[index],
                address(_borrowRequest),
                _collateralAmounts[index]
            );

            //  initiate transfer
            erc20TokenLibrary.transferFromTokens(
                address(_tokens[index]),
                address(_borrower),
                address(_borrowRequest),
                _collateralAmounts[index]
            );

            // update states
            BorrowRequest(_borrowRequest).updateRequest(
                _tokens[index],
                index,
                _collateralAmounts[index],
                _loanAmountRequested
            );
        }

        _state = LoanConfigLibrary.RequestState.OPEN;

        /** EMIT EVENT */
        emit BorrowRequestUpdated(
            _borrowRequest,
            totalCollateralValue,
            _loanAmountRequested
        );

        /** COLLECT ORIGINATION FEE */
        originationFee = protocolManager.calculate_OriginationFee(
            totalCollateralValue
        );

        if (msg.value != totalCollateralValue) revert();
        (bool originationFeePaid, ) = protocolManager.FEE_CONTRACT().call{
            value: originationFee
        }("");

        if (!originationFeePaid)
            revert BorrowRequestFactory__OriginationFeePaymentFailed();

        _state = LoanConfigLibrary.RequestState.OPEN;
        BorrowRequest(address(_borrowRequest)).updateRequestState(_state);
    }

    /*//////////////////////////////////////////////////////////////
                              PRIVATE VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _getRequestDetails(
        address borrowRequest
    )
        private
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
        (
            tokens,
            collateralAmount,
            loanAmountRequested,
            borrower,
            state,
            timeCreated
        ) = BorrowRequest(borrowRequest).getBorrowRequestDetails();

        return (
            tokens,
            collateralAmount,
            loanAmountRequested,
            borrower,
            state,
            timeCreated
        );
    }
}
