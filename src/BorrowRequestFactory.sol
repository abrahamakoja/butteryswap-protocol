// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title BorrowRequestFactory
/// @author ButterySwap Protocol
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details

//  debug @audit
import {Script, console2} from "forge-std/Script.sol";

/*//////////////////////////////////////////////////////////////
                                 IMPORT
    //////////////////////////////////////////////////////////////*/

import {BorrowRequest} from "./BorrowRequest.sol";
import {erc20TokenLibrary} from "./libraries/erc20TokenLibrary.sol";
import {IBorrowRequest} from "./interfaces/IBorrowRequest.sol";
import {IProtocolManager} from "./interfaces/IProtocolManager.sol";
import {ITokenManager} from "./interfaces/ITokenManager.sol";
import {LoanConfigLibrary} from "./libraries/LoanConfigLibrary.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract BorrowRequestFactory is AccessControl, ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error BorrowRequestFactory__InvalidTokenCount(uint256 tokenCount);
    error BorrowRequestFactory__unSupportedToken(address token);
    error BorrowRequestFactory__NoCollateralSent(uint256 collateralAmount);
    error BorrowRequestFactory__InvalidRequest();
    error BorrowRequestFactory__InvalidAddress();
    error BorrowRequestFactory__insufficientPriorityFee();
    error BorrowRequestFactory__collateralAssetMaxLimitReached();
    error BorrowRequestFactory__providedAssetsOutOfRange(
        uint256 MAX_ASSET_LIMIT,
        uint256 numberOfAssetsProvided
    );
    error BorrowRequestFactory__rangeDataMisMatch();
    error BorrowRequestFactory__notOwner();
    error BorrowRequestFactory__RequestNotOpen();
    error BorrowRequestFactory__BorrowRequestFailed();
    error BorrowRequestFactory__PriorityFeePaymentFailed();
    error BorrowRequestFactory__OriginationFeePaymentFailed();
    error LendRequestFactory__insufficientFeeAmount();
    error BorrowRequestFactory__collateralValueMismatch();
    error BorrowRequestFactory__RequestIsPrioritized();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant LIMIT_MARKET = keccak256("LIMIT_MARKET");

    IProtocolManager private immutable s_protocolManager;

    BorrowRequest[] private s_totalNonPrioritizedBorrowRequest;

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

    modifier addressIsValid(address _address) {
        require(
            (_address != address(0)),
            BorrowRequestFactory__InvalidAddress()
        );
        _;
    }

    /** CONSTRUCTOR */
    constructor(address _protocolManager) {
        s_protocolManager = IProtocolManager(_protocolManager);
        bool defaultAdminSet = _grantRole(
            DEFAULT_ADMIN_ROLE,
            s_protocolManager.DEPLOYER()
        );

        bool limitMarketRoleSet = _grantRole(
            LIMIT_MARKET,
            s_protocolManager.LIMIT_MARKET_CONTRACT_ADDRESS()
        );
        require(
            limitMarketRoleSet && defaultAdminSet,
            "Roles allocation Failed"
        );
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
    )
        external
        payable
        addressIsValid(borrower)
        onlyRole(LIMIT_MARKET)
        nonReentrant
        returns (address borrowRequest)
    {
        // @note check health factor of each token
        // @audit return the created request address
        // @audit if value of tokens match requested collateral amount based of ltv
        // @audit integrate enumerable sets
        // @audit loanAmountRequested should be checked based off the ltv of supplied tokens
        // @audit implement proxy clones

        /** CHECKS */
        // uint256 totalCollateralValue; //@audit change this to a helper function that gets value in eth for tokens
        // @audit value at creation time would always differ by completion,
        // do not depend on collateral value for accounting but protocol interest rates at creation
        // interest should be fetched from limit market before passed to factory.

        require(
            (collateralAmount.length == tokens.length),
            BorrowRequestFactory__rangeDataMisMatch()
        );

        if (
            tokens.length == 0 ||
            tokens.length > s_protocolManager.MAX_ASSET_LIMIT()
        ) revert BorrowRequestFactory__InvalidTokenCount(tokens.length);

        borrowRequest = _rawCreateRequest(
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
    ) external payable onlyRole(LIMIT_MARKET) nonReentrant {
        //@audit merge all three priority fee check using ||
        if (
            msg.value <
            s_protocolManager.calculate_PriorityFee(borrowRequest.balance)
        ) revert();

        if (msg.value == 0)
            revert BorrowRequestFactory__insufficientPriorityFee();
        if (
            msg.value !=
            s_protocolManager.calculate_PriorityFee(borrowRequest.balance)
        ) revert();

        require(
            (s_isValidContract[borrowRequest] == true),
            BorrowRequestFactory__InvalidRequest()
        );

        require(
            (s_loanIsPrioritized[borrowRequest] == false),
            BorrowRequestFactory__RequestIsPrioritized()
        );

        /** GET LOAN DETAILS */
        (, , , address _borrower, uint8 _state, ) = _getRequestDetails(
            borrowRequest
        );

        require(
            (_state == uint8(LoanConfigLibrary.RequestState.OPEN)),
            BorrowRequestFactory__RequestNotOpen()
        );

        _state = uint8(LoanConfigLibrary.RequestState.PRIORITIZING);

        IBorrowRequest(borrowRequest).updateRequestState(_state);

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
    ) external payable onlyRole(LIMIT_MARKET) nonReentrant {
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
            uint8 _state,

        ) = _getRequestDetails(borrowRequest);

        if (_state != uint8(LoanConfigLibrary.RequestState.OPEN))
            revert BorrowRequestFactory__RequestNotOpen();
        _state = uint8(LoanConfigLibrary.RequestState.ADDING_LIQUIDITY);
        IBorrowRequest(borrowRequest).updateRequestState(_state);

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
        if (!(_tokens.length <= s_protocolManager.MAX_ASSET_LIMIT())) {
            revert BorrowRequestFactory__collateralAssetMaxLimitReached();
        }

        // check if new token length exceeds available slot
        if (
            tokens.length >
            (s_protocolManager.MAX_ASSET_LIMIT() - _tokens.length)
        ) {
            revert BorrowRequestFactory__providedAssetsOutOfRange(
                s_protocolManager.MAX_ASSET_LIMIT(),
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
    ) external payable onlyRole(LIMIT_MARKET) nonReentrant {
        if (s_isValidContract[borrowRequest] == false)
            revert BorrowRequestFactory__InvalidRequest();
        /** GET LOAN DETAILS */
        (
            address[] memory _tokens,
            uint256[] memory _collateralAmount,
            ,
            address _borrower,
            uint8 _state,

        ) = _getRequestDetails(borrowRequest);

        /** CHECKS */

        if (_state != uint8(LoanConfigLibrary.RequestState.OPEN))
            revert BorrowRequestFactory__RequestNotOpen();
        _state = uint8(LoanConfigLibrary.RequestState.CANCELLING);
        IBorrowRequest(borrowRequest).updateRequestState(_state);

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

    function getTotalRequests()
        external
        view
        returns (
            uint256 totalNonPrioritizedBorrowRequests,
            uint256 totalPrioritizedBorrowRequest
        )
    {
        return (
            s_totalNonPrioritizedBorrowRequest.length,
            s_prioritizedBorrowRequests.length
        );
    }

    function getNonPrioritizedRequestViaIndex(
        uint256 index
    ) external view returns (address request) {
        return address(s_totalNonPrioritizedBorrowRequest[index]);
    }

    function getPrioritizedRequestViaIndex(
        uint256 index
    ) external view returns (address request) {
        return address(s_prioritizedBorrowRequests[index]);
    }

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
    ) private returns (address _borrowRequest) {
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
                address(s_protocolManager)
            )
        returns (BorrowRequest request) {
            borrowRequest = request;
            for (uint256 index = 0; index < _tokens.length; index++) {
                // check each token is listed
                if (
                    !ITokenManager(s_protocolManager.TokenManager())
                        .checkIsTokenListed(address(_tokens[index]))
                ) revert BorrowRequestFactory__unSupportedToken(_tokens[index]);

                if (_collateralAmount[index] == 0)
                    revert BorrowRequestFactory__NoCollateralSent(
                        _collateralAmount[index]
                    );

                totalCollateralValue += s_protocolManager
                    .calculate_CollateralValue(_collateralAmount[index]); //@audit token manager handles collateral value
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
                s_totalNonPrioritizedBorrowRequest.push(borrowRequest);

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

        priorityFee = s_protocolManager.calculate_PriorityFee(
            totalCollateralValue
        );

        originationFee = s_protocolManager.calculate_OriginationFee(
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
            (bool priorityFeePaid, ) = s_protocolManager.FEE_CONTRACT().call{
                value: fee
            }("");
            if (!priorityFeePaid)
                revert BorrowRequestFactory__PriorityFeePaymentFailed();
        } else {
            /** COLLECT ORIGINATION FEE */
            (bool originationFeePaid, ) = s_protocolManager.FEE_CONTRACT().call{
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

        // return borrow request address
        _borrowRequest = address(borrowRequest);
    }

    function _rawPrioritizeLoanRequest(
        address _borrowRequest,
        address _borrower,
        uint8 _state
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

        _state = uint8(LoanConfigLibrary.RequestState.OPEN);
        emit BorrowRequestPrioritized(_borrowRequest, msg.value);

        /** COLLECT PRIORITY FEE */
        (bool priorityFeePaid, ) = address(s_protocolManager.FEE_CONTRACT())
            .call{value: msg.value}("");
        if (!priorityFeePaid)
            revert BorrowRequestFactory__PriorityFeePaymentFailed();

        IBorrowRequest(_borrowRequest).updateRequestState(uint8(_state));
    }

    function _rawCancelRequest(
        address _borrower,
        address _borrowRequest,
        address[] memory _tokens,
        uint256[] memory _collateralAmount,
        uint8 _state
    ) private {
        uint256 cancellationFee;
        uint256 totalCollateralValue; //@audit change this to a helper function that gets value in eth for tokens

        /** EFFECTS */

        for (uint256 index = 0; index < _collateralAmount.length; index++) {
            totalCollateralValue += _collateralAmount[index];
        }
        cancellationFee = s_protocolManager.calculateCancellationFee(
            totalCollateralValue
        );
        _state = uint8(LoanConfigLibrary.RequestState.CANCELLED);

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
        (bool success, ) = s_protocolManager.FEE_CONTRACT().call{
            value: cancellationFee
        }("");
        if (!success) {
            revert();
        }

        /** UPDATE STATE */
        IBorrowRequest(_borrowRequest).updateRequestState(uint8(_state)); // @audit try resetting
    }

    function _rawAddLiquidity(
        address _borrower,
        address _borrowRequest,
        uint256 _loanAmountRequested,
        address[] memory _tokens,
        uint256[] memory _collateralAmounts,
        uint8 _state
    ) private {
        /** EFFECTS */
        uint256 totalCollateralValue;
        uint256 originationFee;

        // check if asset is supported by protocol / approve and execute transfer within the same loop
        for (uint256 index = 0; index > _tokens.length; index++) {
            if (
                ITokenManager(s_protocolManager.TokenManager())
                    .checkIsTokenListed(address(_tokens[index]))
            ) {
                revert BorrowRequestFactory__unSupportedToken(
                    address(_tokens[index])
                );
            }

            totalCollateralValue += s_protocolManager.calculate_CollateralValue(
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
            IBorrowRequest(_borrowRequest).updateRequest(
                _tokens[index],
                index,
                _collateralAmounts[index],
                _loanAmountRequested
            );
        }

        _state = uint8(LoanConfigLibrary.RequestState.OPEN);

        /** EMIT EVENT */
        emit BorrowRequestUpdated(
            _borrowRequest,
            totalCollateralValue,
            _loanAmountRequested
        );

        /** COLLECT ORIGINATION FEE */
        originationFee = s_protocolManager.calculate_OriginationFee(
            totalCollateralValue
        );

        _state = uint8(LoanConfigLibrary.RequestState.OPEN);
        IBorrowRequest(address(_borrowRequest)).updateRequestState(
            uint8(_state)
        );

        if (msg.value != totalCollateralValue) revert();
        (bool originationFeePaid, ) = s_protocolManager.FEE_CONTRACT().call{
            value: originationFee
        }("");

        if (!originationFeePaid)
            revert BorrowRequestFactory__OriginationFeePaymentFailed();
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
            uint8 state,
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
        ) = IBorrowRequest(borrowRequest).getRequestDetails();

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
