// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * ███████████              █████     █████                                   █████████                                     
*▒▒███▒▒▒▒▒███            ▒▒███     ▒▒███                                   ███▒▒▒▒▒███                                    
* ▒███    ▒███ █████ ████ ███████   ███████    ██████  ████████  █████ ████▒███    ▒▒▒  █████ ███ █████  ██████   ████████ 
* ▒██████████ ▒▒███ ▒███ ▒▒▒███▒   ▒▒▒███▒    ███▒▒███▒▒███▒▒███▒▒███ ▒███ ▒▒█████████ ▒▒███ ▒███▒▒███  ▒▒▒▒▒███ ▒▒███▒▒███
* ▒███▒▒▒▒▒███ ▒███ ▒███   ▒███      ▒███    ▒███████  ▒███ ▒▒▒  ▒███ ▒███  ▒▒▒▒▒▒▒▒███ ▒███ ▒███ ▒███   ███████  ▒███ ▒███
* ▒███    ▒███ ▒███ ▒███   ▒███ ███  ▒███ ███▒███▒▒▒   ▒███      ▒███ ▒███  ███    ▒███ ▒▒███████████   ███▒▒███  ▒███ ▒███
* ███████████  ▒▒████████  ▒▒█████   ▒▒█████ ▒▒██████  █████     ▒▒███████ ▒▒█████████   ▒▒████▒████   ▒▒████████ ▒███████ 
▒▒▒▒▒▒▒▒▒▒▒    ▒▒▒▒▒▒▒▒    ▒▒▒▒▒     ▒▒▒▒▒   ▒▒▒▒▒▒  ▒▒▒▒▒       ▒▒▒▒▒███  ▒▒▒▒▒▒▒▒▒     ▒▒▒▒ ▒▒▒▒     ▒▒▒▒▒▒▒▒  ▒███▒▒▒                                                                   ███ ▒███                                        ▒███     
                                                                ▒▒██████                                         █████    
                                                                 ▒▒▒▒▒▒                                         ▒▒▒▒▒   

 ███████████                      █████                               ████ 
▒▒███▒▒▒▒▒███                    ▒▒███                               ▒▒███ 
 ▒███    ▒███ ████████   ██████  ███████    ██████   ██████   ██████  ▒███ 
 ▒██████████ ▒▒███▒▒███ ███▒▒███▒▒▒███▒    ███▒▒███ ███▒▒███ ███▒▒███ ▒███ 
 ▒███▒▒▒▒▒▒   ▒███ ▒▒▒ ▒███ ▒███  ▒███    ▒███ ▒███▒███ ▒▒▒ ▒███ ▒███ ▒███ 
 ▒███         ▒███     ▒███ ▒███  ▒███ ███▒███ ▒███▒███  ███▒███ ▒███ ▒███ 
 █████        █████    ▒▒██████   ▒▒█████ ▒▒██████ ▒▒██████ ▒▒██████  █████
▒▒▒▒▒        ▒▒▒▒▒      ▒▒▒▒▒▒     ▒▒▒▒▒   ▒▒▒▒▒▒   ▒▒▒▒▒▒   ▒▒▒▒▒▒  ▒▒▒▒▒ 
                                                                           
                                                                           
                                                                             
 */

/// @title BorrowRequestFactory
/// @author ButterySwap Protocol
/// @notice  @audit Explain to an end user what this does
/// @dev @audit Explain to a developer any extra details

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
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract BorrowRequestFactory is
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuard
{
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
    error BorrowRequestFactory__insufficientFeeAmount();
    error BorrowRequestFactory__collateralValueMismatch();
    error BorrowRequestFactory__RequestIsPrioritized();

    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    struct RequestInfo {
        address borrower;
        address request;
        uint256 totalAmountRequested;
        uint256 position;
        bool isValid;
        bool prioritized;
    }

    struct PriorityList {
        address request;
        uint256 position;
    }

    struct TokenInfo {
        address tokenAddress;
        uint256 amount;
        uint256 price;
        uint256 ethValueAtRequestTime;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public limitMarketContract;

    address private _beacon;

    uint256 private _requestCount;
    uint256 private _priorityCount;

    IProtocolManager private _protocolManager;

    BorrowRequest[] private _totalUnPrioritizedRequests;

    BorrowRequest[] private _prioritizedRequests;

    mapping(address borrower => address[] borrowRequestAddresses)
        private userToBorrowRequestAddresses;
    mapping(address borrower => RequestInfo[] requestInfo)
        private userToRequests;
    mapping(uint256 index => PriorityList[] priorityList)
        private indexToPrioritizedRequests;

    mapping(address borrowRequest => address borrower)
        private borrowRequestToBorrower;

    mapping(address borrower => address[] prioritizedBorrowRequests)
        private userToPrioritizedBorrowRequestAddresses;

    mapping(address prioritizedBorrowRequest => address borrower)
        private prioritizedBorrowRequestToBorrower;

    mapping(address loanRequest => bool prioritized)
        private s_loanIsPrioritized;

    mapping(address => bool) private s_isValidContract;

    mapping(address borrowRequest => TokenInfo[] tokenInfo)
        private collateralToValue;

    mapping(address borrower => uint256 totalAmountRequested)
        private borrowerToTotalAmountRequested;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event BorrowRequestFactoryInitialized(
        address indexed borrowRequestFactoryAddress
    );
    event ImplementationUpgraded(address indexed newImplementation);

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

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function initialize(
        address protocolManager,
        address beacon
    ) public initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();

        limitMarketContract = keccak256("limitMarketContract");
        _protocolManager = IProtocolManager(protocolManager);
        _beacon = beacon;
        _requestCount = 0;
        address deployer = _protocolManager.deployer();

        bool adminRoleGranted = _grantRole(DEFAULT_ADMIN_ROLE, deployer);

        bool limitMarketContractRoleGranted = _grantRole(
            limitMarketContract,
            _protocolManager.LIMIT_MARKET_CONTRACT_ADDRESS()
        );
        require(adminRoleGranted && limitMarketContractRoleGranted);
        _protocolManager.updateBorrowRequestFactoryContract(
            address(this),
            deployer
        );
        emit BorrowRequestFactoryInitialized(address(this));
    }

    function upgradeImplementation(
        address _newImplementation
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        UpgradeableBeacon(_beacon).upgradeTo({
            newImplementation: _newImplementation
        });
        _beacon = _newImplementation;
        emit ImplementationUpgraded({newImplementation: _newImplementation});
    }

    function _authorizeUpgrade(
        address
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new BorrowRequest instance
    /// @param collateralAmount The amount of collateral to be locked
    /// @param tokens The list of tokens to be used as collateral
    /// @param borrower The address of the enforcer contract
    /// @param priority The address of the enforcer contract
    /// @return borrowRequest
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
        onlyRole(limitMarketContract)
        nonReentrant
        returns (address borrowRequest)
    {
        // @note check health factor of each token
        // @audit check fee here
        // @audit if value of tokens match requested collateral amount based of ltv
        // @audit integrate enumerable sets
        // @audit loanAmountRequested should be checked based off the ltv of supplied tokens
        // uint256 totalCollateralValue;
        //@audit change this to a helper function that gets value in eth for tokens
        // @audit value at creation time would always differ by completion,
        // do not depend on collateral value for accounting but protocol interest rates at creation
        // interest should be fetched from limit market before passed to factory.

        /// CHECKS

        borrowRequest = _rawCreateRequest({
            _collateralAmount: collateralAmount,
            _loanAmountRequested: loanAmountRequested,
            _tokens: tokens,
            _borrower: borrower,
            _priority: priority
        });
    }

    function prioritizeLoanRequest(
        address borrower,
        address borrowRequest
    ) external payable onlyRole(limitMarketContract) nonReentrant {
        //@audit merge all three priority fee check using ||
        if (
            msg.value <
            _protocolManager.calculate_PriorityFee(borrowRequest.balance)
        ) revert BorrowRequestFactory__insufficientPriorityFee();

        if (msg.value == 0)
            revert BorrowRequestFactory__insufficientPriorityFee();
        if (
            msg.value !=
            _protocolManager.calculate_PriorityFee(borrowRequest.balance)
        ) revert BorrowRequestFactory__insufficientPriorityFee();

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
    ) external payable onlyRole(limitMarketContract) nonReentrant {
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
        if (!(_tokens.length <= _protocolManager.MAX_ASSET_LIMIT())) {
            revert BorrowRequestFactory__collateralAssetMaxLimitReached();
        }

        // check if new token length exceeds available slot
        if (
            tokens.length >
            (_protocolManager.MAX_ASSET_LIMIT() - _tokens.length)
        ) {
            revert BorrowRequestFactory__providedAssetsOutOfRange(
                _protocolManager.MAX_ASSET_LIMIT(),
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
    ) external payable onlyRole(limitMarketContract) nonReentrant {
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
            _totalUnPrioritizedRequests.length,
            _prioritizedRequests.length
        );
    }

    function getNonPrioritizedRequestViaIndex(
        uint256 index
    ) external view returns (address request) {
        return address(_totalUnPrioritizedRequests[index]);
    }

    function getPrioritizedRequestViaIndex(
        uint256 index
    ) external view returns (address request) {
        return address(_prioritizedRequests[index]);
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
        // EFFECTS
        uint256 totalCollateralValue;
        uint256 originationFee;
        uint256 priorityFee;

        bytes memory initData = abi.encodeWithSelector(
            bytes4(
                keccak256(
                    "initialize(address,uint256[],uint256,address[],uint256,address)"
                )
            ),
            _borrower,
            _collateralAmount,
            _loanAmountRequested,
            _tokens,
            block.timestamp,
            address(_protocolManager)
        );

        /// INTERACTIONS

        BeaconProxy borrowRequestProxy = new BeaconProxy(
            address(_beacon),
            initData
        );

        for (uint256 index = 0; index < _tokens.length; index++) {
            TokenInfo memory tokenInfo = TokenInfo({
                tokenAddress: _tokens[index],
                amount: _collateralAmount[index],
                price: 0,
                ethValueAtRequestTime: 0
            });

            collateralToValue[address(borrowRequestProxy)].push(tokenInfo);

            /// @dev transfer tokens to borrowRequest contract
            erc20TokenLibrary.transferFromTokens(
                _tokens[index],
                address(_borrower),
                address(borrowRequestProxy),
                _collateralAmount[index]
            );

            //@audit this should capture the sum of all token eth value at request time
            totalCollateralValue++;
        }

        priorityFee = _protocolManager.calculate_PriorityFee(
            totalCollateralValue
        );

        originationFee = _protocolManager.calculate_OriginationFee(
            totalCollateralValue
        );

        RequestInfo memory requestInfo = RequestInfo({
            borrower: _borrower,
            request: address(borrowRequestProxy),
            totalAmountRequested: totalCollateralValue,
            position: _requestCount,
            isValid: true,
            prioritized: _priority
        });

        userToRequests[_borrower].push(requestInfo);

        if (_priority) {
            PriorityList memory priorityInfo = PriorityList({
                request: address(borrowRequestProxy),
                position: _priorityCount
            });
            indexToPrioritizedRequests[_priorityCount].push(priorityInfo);
            _priorityCount++;
        }

        _requestCount++;

        borrowerToTotalAmountRequested[_borrower] += totalCollateralValue;

        /// EVENTS

        emit BorrowRequestCreated(
            _borrower,
            address(borrowRequestProxy),
            totalCollateralValue
        );
        if (_priority)
            emit BorrowRequestPrioritized(address(borrowRequestProxy));

        /// INTERACTIONS

        /// @dev collect fee
        if (_priority) {
            /// COLLECT ORIGINATION FEE + PRIORITY FEE
            uint256 fee = priorityFee + originationFee;
            (bool priorityFeePaid, ) = _protocolManager.FEE_CONTRACT().call{
                value: fee
            }("");

            require(
                priorityFeePaid,
                BorrowRequestFactory__PriorityFeePaymentFailed()
            );
        } else {
            /// COLLECT ONLY ORIGINATION FEE
            (bool originationFeePaid, ) = _protocolManager.FEE_CONTRACT().call{
                value: originationFee
            }("");
            require(
                originationFeePaid,
                BorrowRequestFactory__OriginationFeePaymentFailed()
            );
        }

        // return borrow request address
        _borrowRequest = address(borrowRequestProxy);
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

        _prioritizedRequests.push(BorrowRequest(_borrowRequest));

        userToPrioritizedBorrowRequestAddresses[_borrower].push(
            address(_borrowRequest)
        );

        _state = uint8(LoanConfigLibrary.RequestState.OPEN);
        emit BorrowRequestPrioritized(_borrowRequest, msg.value);

        /** COLLECT PRIORITY FEE */
        (bool priorityFeePaid, ) = address(_protocolManager.FEE_CONTRACT())
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
        cancellationFee = _protocolManager.calculateCancellationFee(
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
        (bool success, ) = _protocolManager.FEE_CONTRACT().call{
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
                ITokenManager(_protocolManager.TokenManager())
                    .checkIsTokenListed(address(_tokens[index]))
            ) {
                revert BorrowRequestFactory__unSupportedToken(
                    address(_tokens[index])
                );
            }

            totalCollateralValue += _protocolManager.calculate_CollateralValue(
                _collateralAmounts[index]
            );

            /**UPDATE MAPPING */
            borrowerToTotalAmountRequested[_borrower] += _collateralAmounts[
                index
            ];

            // collateralToValue[address(_borrowRequest)][
            //     _tokens[index]
            // ] += _collateralAmounts[index];

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
        originationFee = _protocolManager.calculate_OriginationFee(
            totalCollateralValue
        );

        _state = uint8(LoanConfigLibrary.RequestState.OPEN);
        IBorrowRequest(address(_borrowRequest)).updateRequestState(
            uint8(_state)
        );

        if (msg.value != totalCollateralValue) revert();
        (bool originationFeePaid, ) = _protocolManager.FEE_CONTRACT().call{
            value: originationFee
        }("");

        if (!originationFeePaid)
            revert BorrowRequestFactory__OriginationFeePaymentFailed();
    }

    /*//////////////////////////////////////////////////////////////
                              PRIVATE VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _getRequestDetails(
        address borrowRequestProxy
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
        ) = IBorrowRequest(borrowRequestProxy).getRequestDetails();

        return (
            tokens,
            collateralAmount,
            loanAmountRequested,
            borrower,
            state,
            timeCreated
        );
    }

    // gap
    uint256[60] private __gap;
}
