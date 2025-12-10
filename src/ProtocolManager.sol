// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// debug
import {Script, console2} from "forge-std/Script.sol";

/*//////////////////////////////////////////////////////////////
                                 IMPORTS
    //////////////////////////////////////////////////////////////*/

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ILimitMarket} from "./interfaces/ILimitMarket.sol";

// debug
/// @audit remove before production
import {Script, console2} from "forge-std/Script.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract ProtocolManager is
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuard
{
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ProtocolManager__invalidAddress();
    error ProtocolManager__unAuthorizedCaller();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public MANAGER;
    address public Enforcer;
    address public BorrowRequestFactory;
    address public LendRequestFactory;
    address public TokenManager;
    uint256 public minimumDeposit;
    address public deployer;
    address public TOKEN_MANAGER_CONTRACT;
    address public LIMIT_MARKET_CONTRACT_ADDRESS;
    address public borrowRequestImplementation;
    /// @dev listing fee to be paid by caller when creating a listing request.
    uint256 public LISTING_FEE;
    address public FEE_CONTRACT;
    uint256 public MAX_ASSET_LIMIT;
    uint256 public ORIGINATION_FEE;
    uint256 public CANCELLATION_FEE;
    uint256 public SETTLEMENT_FEE;
    uint256 public INDEX_PRECISION;

    uint24 public UNISWAP_V2_ORACLE_FEE;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        MANAGER = keccak256("MANAGER");
        _grantRole(MANAGER, msg.sender);

        //    assign storage values
        deployer = msg.sender;
        LISTING_FEE = 1 ether;
        FEE_CONTRACT = 0xDfCF9329f7cF00eC3A0a53109A1287C4d5A49C05;
        MAX_ASSET_LIMIT = 6;
        ORIGINATION_FEE = 6;
        CANCELLATION_FEE = 10;
        SETTLEMENT_FEE = 6;
        INDEX_PRECISION = 1;
        UNISWAP_V2_ORACLE_FEE = 3000;
    }

    function _authorizeUpgrade(
        address
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier addressValidated(address _address) {
        if (_address == address(0)) {
            revert ProtocolManager__invalidAddress();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function calculate_CollateralValue(
        uint256 amount
    ) external pure returns (uint256) {
        return amount;
    }

    function calculate_PriorityFee(
        uint256 amount
    ) external pure returns (uint256) {
        return amount / 3;
    }

    function calculate_OriginationFee(
        uint256 amount
    ) external pure returns (uint256) {
        return amount / 3;
    }

    function updateEnforcerContract(
        address _address
    ) external addressValidated(_address) onlyRole(MANAGER) {}
    function calculateTokenListingFee(
        address token
    ) external pure returns (uint256 fee) {
        // require(token != address(0));
        //@audit unused variable
        return 1 ether;
    }
    function setLimitMarketContractAddress(
        address limitMarketAddress
    ) external addressValidated(limitMarketAddress) {
        require(
            limitMarketAddress != address(0),
            ProtocolManager__invalidAddress()
        );
        console2.log("protocol manager msg.sender", msg.sender);
        console2.log("protocol manager deployer", deployer);
        LIMIT_MARKET_CONTRACT_ADDRESS = limitMarketAddress;
    }
    function setBorrowRequestImplementation(
        address _borrowRequestImplementation
    )
        external
        addressValidated(_borrowRequestImplementation)
        onlyRole(MANAGER)
    {
        console2.log(
            "borrow request implementation",
            _borrowRequestImplementation
        );
        borrowRequestImplementation = _borrowRequestImplementation;
    }

    // @audit require msg.sender to be factory or admin ,lock after execution
    function updateBorrowRequestFactoryContract(
        address borrowRequestFactory,
        address manager
    )
        external
        addressValidated(borrowRequestFactory)
        addressValidated(manager)
    {
        require(hasRole(MANAGER, manager));
        BorrowRequestFactory = borrowRequestFactory;
    }
    function updateTokenManagerContract(
        address tokenManager,
        address manager
    ) external addressValidated(tokenManager) addressValidated(manager) {
        require(hasRole(MANAGER, manager));
        TokenManager = tokenManager;
    }
    function updateLendRequestFactoryContract(
        address _address
    ) external addressValidated(_address) onlyRole(MANAGER) {}
    function updateTokenManagerContract(
        address _address
    ) external addressValidated(_address) onlyRole(MANAGER) {}

    function calculateAmountMinus_OriginationFee(
        uint256 collateraValue
    ) external view returns (uint256) {
        return (collateraValue - (calculateOriginationFee(collateraValue)));
    }

    function calculateAmountMinus_SettlementFee(
        uint256 collateraValue
    ) external view returns (uint256) {
        return (collateraValue - (calculateSettlementFee(collateraValue))); // @note change magic number to precision constant
    }

    function calculateAmountMinus_CancellationFee(
        uint256 amount
    ) external view returns (uint256) {
        return (amount - (calculateCancellationFee(amount)));
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC, INTERNAL & PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // @audit fix the fees
    function calculateCancellationFee(
        uint256 collateraValue
    ) private view returns (uint256) {
        return ((collateraValue * CANCELLATION_FEE) / 100) * 1 ether;
    }
    function calculateOriginationFee(
        uint256 collateraValue
    ) private view returns (uint256) {
        return ((collateraValue * ORIGINATION_FEE) / 100) * 1 ether;
    }

    // change to settlement fee
    function calculateSettlementFee(
        uint256 collateraValue
    ) private view returns (uint256) {
        return (collateraValue * SETTLEMENT_FEE) / 100;
    }
}
