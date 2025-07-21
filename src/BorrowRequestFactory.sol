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

import {BorrowRequest_v1} from "./BorrowRequest_v1.sol";
import {erc20TokenLibrary} from "./libraries/erc20TokenLibrary.sol";
import {iProtocolManager} from "./interfaces/iProtocolManager.sol";
import {iTokenManager} from "./interfaces/iTokenManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {LoanConfigLibrary} from "./libraries/LoanConfigLibrary.sol";

contract BorrowRequestFactory is Ownable {
    //@audit ensure states are updated after updates creation and deletion and always emit after state change
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error BorrowRequestFactory__InvalidTokenCount(uint256 tokenCount);
    error BorrowRequestFactory__unSupportedToken(address token);
    error BorrowRequestFactory__NoCollateralSent(uint256 collateralAmount);
    error BorrowRequestFactory__inValidContractAddress();
    error BorrowRequestFactory__inValidRequest();
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

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    //@audit check all mapping
    BorrowRequest_v1[] private totalBorrowRequests;

    BorrowRequest_v1[] private s_prioritizedBorrowRequests;

    iProtocolManager private immutable protocolManager;

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

    /** CONSTRUCTOR */
    constructor(address _protocolManager) Ownable(msg.sender) {
        protocolManager = iProtocolManager(_protocolManager);
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
    ) external payable onlyLimitMarket {
        // @note check health factor of each token
        // @audit if value of tokens match requested collateral amount based of ltv

        /** CHECKS */
        // uint256 totalCollateralValue; //@audit change this to a helper function that gets value in eth for tokens
        uint256 originationFee;
        uint256 priorityFee;

        if (collateralAmount.length != tokens.length)
            revert BorrowRequestFactory__rangeDataMisMatch();

        if (
            tokens.length == 0 ||
            tokens.length > protocolManager.MAX_ASSET_LIMIT()
        ) revert BorrowRequestFactory__InvalidTokenCount(tokens.length);

        for (uint index = 0; index < tokens.length; index++) {
            if (collateralAmount[index] == 0)
                revert BorrowRequestFactory__NoCollateralSent(
                    collateralAmount[index]
                );
            totalCollateralValue += protocolManager.calculate_CollateralValue(
                collateralAmount[index]
            );
        }

        originationFee = protocolManager.calculate_OriginationFee(
            totalCollateralValue
        );
        priorityFee = protocolManager.PRIORITY_FEE();
        if (
            msg.value == 0 ||
            msg.value < originationFee ||
            msg.value < priorityFee
        ) revert LendRequestFactory__insufficientFeeAmount();
        _rawCreateRequest(
            collateralAmount,
            loanAmountRequested,
            tokens,
            borrower,
            priority,
            totalCollateralValue,
            originationFee,
            priorityFee
        );
    }

    function addLiquidity(
        address borrower,
        address borrowRequest,
        address[] calldata tokens,
        uint256[] calldata collateralAmounts,
        uint256 loanAmountRequested
    ) external payable onlyLimitMarket {
        // @audit if value of tokens match requested collateral amount based of ltv
        // check borrowRequest is valid
        if (s_isValidContract[borrowRequest] == false)
            revert BorrowRequestFactory__inValidRequest();
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
        LoanConfigLibrary.RequestState state = LoanConfigLibrary
            .RequestState
            .ADDING_LIQUIDITY;
        BorrowRequest_v1(borrowRequest).updateRequestState(state);

        // check collateralAmount and tokens match in length
        if (collateralAmounts.length != tokens.length) {
            revert BorrowRequestFactory__rangeDataMisMatch();
        }

        // check borrower owns borrow request
        if (
            borrowRequestToBorrower[borrowRequest] != address(borrower) ||
            prioritizedBorrowRequestToBorrower[borrowRequest] !=
            address(borrower) ||
            address(borrower) != address(_borrower)
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
            state,
            loanAmountRequested,
            tokens,
            collateralAmounts
        );
    }

    function cancelRequest(
        address borrower,
        address borrowRequest
    ) external payable onlyLimitMarket {
        (
            address[] memory tokens,
            uint256[] memory collateralAmount,
            ,
            ,
            address _borrower,
            uint8 state,

        ) = BorrowRequest_v1(borrowRequest).getBorrowRequestDetails();

        /** CHECKS */

        if (state != LoanConfigLibrary.RequestState.OPEN)
            revert BorrowRequestFactory__RequestNotOpen();
        state = LoanConfigLibrary.RequestState.CANCELLING;

        // check borrowRequest is valid
        if (s_isValidContract[borrowRequest] == false)
            revert BorrowRequestFactory__inValidRequest();

        // check borrower owns borrow request
        if (
            borrowRequestToBorrower[borrowRequest] != address(borrower) ||
            prioritizedBorrowRequestToBorrower[borrowRequest] !=
            address(borrower) ||
            address(borrower) != address(_borrower)
        ) revert BorrowRequestFactory__notOwner();

        _rawCancelRequest(
            borrower,
            borrowRequest,
            tokens,
            collateralAmount,
            state
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
    //         BorrowRequest_v1 borrowRequest_v1 = BorrowRequest_v1(
    //             payable(address(s_prioritizedBorrowRequests[i]))
    //         );
    //         uint8 status = uint8(borrowRequest_v1.getRequestState());
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
    //         BorrowRequest_v1 borrowRequest_v1 = BorrowRequest_v1(
    //             payable(address(totalBorrowRequests[i]))
    //         );
    //         uint8 status = uint8(borrowRequest_v1.getRequestState());
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

    /// @notice Internal function to create a new BorrowRequest_v1 instance
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
        BorrowRequest_v1 BorrowRequest;
        try
            new BorrowRequest_v1(
                _borrower,
                _collateralAmount,
                _loanAmountRequested,
                _tokens,
                block.timestamp,
                address(protocolManager)
            )
        returns (BorrowRequest_v1 _BorrowRequest) {
            BorrowRequest = _BorrowRequest;
            for (uint256 index = 0; index < _tokens.length; index++) {
                // check each token is listed
                if (
                    !iTokenManager(protocolManager.TokenManager())
                        .checkTokenIsListed(_tokens[index])
                ) revert BorrowRequestFactory__unSupportedToken(_tokens[index]);

                if (_collateralAmount[index] == 0)
                    revert BorrowRequestFactory__NoCollateralSent(
                        _collateralAmount[index]
                    );
                totalCollateralValue += protocolManager
                    .calculate_CollateralValue(_collateralAmount[index]);

                // Reset the allowance to the exact collateralAmount
                erc20TokenLibrary.approveTokens(
                    _tokens[index],
                    address(this),
                    _collateralAmount[index]
                );
    
                collateralToValue[address(BorrowRequest)][
                    _tokens[index]
                ] = _collateralAmount[index];
            }

            if (_priority) {
              
                s_loanIsPrioritized[address(BorrowRequest)] = true;

                prioritizedBorrowRequestToBorrower[
                    address(BorrowRequest)
                ] = address(_borrower);

                s_prioritizedBorrowRequests.push(BorrowRequest);

                userToPrioritizedBorrowRequestAddresses[_borrower].push(
                    address(BorrowRequest)
                );
            } else {
                totalBorrowRequests.push(BorrowRequest);

                borrowRequestToBorrower[address(BorrowRequest)] = address(
                    _borrower
                );

                userToBorrowRequestAddresses[_borrower].push(
                    address(BorrowRequest)
                );
            }
        } catch {
            revert BorrowRequestFactory__BorrowRequestFailed();
        }
        if (_loanAmountRequested < totalCollateralValue)
          revert   BorrowRequestFactory__collateralValueMismatch();//@audit change to ltv check
        priorityFee = protocolManager.calculate_PriorityFee( totalCollateralValue);
        originationFee = protocolManager.calculate_OriginationFee(
            totalCollateralValue
        );
        if (msg.value != originationFee) revert();

        borrowerToTotalAmountRequested[_borrower] += totalCollateralValue;
        s_isValidContract[address(BorrowRequest)] = true;

        /** EMIT EVENTS */
        emit BorrowRequestCreated(
            _borrower,
            address(BorrowRequest),
            totalCollateralValue
        );
        if (_priority == true)
            emit BorrowRequestPrioritized(address(BorrowRequest));

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
            if (!originationFeePaid)
                revert BorrowRequestFactory__OriginationFeePaymentFailed();
        }

        /** TRANSFER TOKENS TO BORROW REQUEST CONTRACT */
        for (uint256 index = 0; index < _tokens.length; index++) {
            erc20TokenLibrary.transferFromTokens(
                _tokens[index],
                address(_borrower),
                address(BorrowRequest),
                _collateralAmount[index]
            );
        }
    }

    function _rawCancelRequest(
        address _borrower,
        address _borrowRequest,
        uint256[] memory _tokens,
        uint256[] memory _collateralAmount,
        uint8 _state
    ) private {
        uint256 cancellationFee;
        uint256 totalCollateralValue; //@audit change this to a helper function that gets value in eth for tokens

        /** EFFECTS */

        for (uint256 index = 0; index < _collateralAmount.length; index++) {
            totalCollateralValue += _collateralAmount[index];
            cancellationFee += protocolManager.calculateCancellationFee(
                _collateralAmount[index]
            );
        }

        /**UPDATE MAPPINGS */
        s_isValidContract[_borrowRequest] = false;
        borrowerToTotalAmountRequested[_borrower] -= totalCollateralValue;
        if (s_loanIsPrioritized[_borrowRequest]) {
            s_loanIsPrioritized[_borrowRequest] = false;
        }

        /** INTERACTIONS */

        /** COLLECT CANCELLATION FEE */
        (bool success, ) = payable(protocolManager.FEE_CONTRACT()).call{
            value: cancellationFee
        }("");

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

        _state = LoanConfigLibrary.RequestState.CANCELLED;
        emit BorrowRequestCancelled(
            BorrowRequest_v1(_borrowRequest).i_Borrower,
            address(_borrowRequest),
            totalCollateralValue,
            address(_borrowRequest).balance
        );
    }

    function _rawAddLiquidity(
        address _borrower,
        address _borrowRequest,
        uint256 _loanAmountRequested,
        address[] memory _tokens,
        uint256[] memory _collateralAmounts
    ) private {
        /** EFFECTS */
        uint256 originationFee = protocolManager.calculate_OriginationFee(
            msg.value
        );
        uint256 depositMinusFee = msg.value - originationFee;
        LoanConfigLibrary.RequestState _state = LoanConfigLibrary
            .RequestState
            .OPEN;

        // check if asset is supported by protocol / approve and execute transfer within the same loop
        for (uint256 index = 0; index > _tokens.length; index++) {
            if (
                iTokenManager(protocolManager.TokenManager())
                    .checkTokenIsListed(_tokens[index])
            ) {
                revert BorrowRequestFactory__unSupportedToken(
                    address(_tokens[index])
                );
            }
            /**UPDATE MAPPING */
            borrowerToTotalAmountRequested[_borrower] += _collateralAmounts[
                index
            ];
            //  approve tokens
            erc20TokenLibrary.approveTokens(
                _tokens[index],
                address(_borrowRequest),
                _collateralAmounts[index]
            );

            //  initiate transfer
            BorrowRequest_v1(_borrowRequest).updateRequest(
                _tokens[index],
                index,
                _collateralAmounts[index],
                _loanAmountRequested
            );

            // interactions
            erc20TokenLibrary.transferFromTokens(
                address(_tokens[index]),
                address(_borrower),
                address(_borrowRequest),
                _collateralAmounts[index]
            );
        }
        /** COLLECT ORIGINATION FEE */

        _state = LoanConfigLibrary.RequestState.OPEN;
        BorrowRequest_v1(address(_borrowRequest)).updateRequestState(_state);
    }

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
        ) = BorrowRequest_v1(borrowRequest).getBorrowRequestDetails();

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
