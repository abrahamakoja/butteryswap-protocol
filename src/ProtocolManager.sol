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

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract ProtocolManager is
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ProtocolManager__invalidAddress();
    error ProtocolManager__unAuthorizedCaller();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant MANAGER = keccak256("MANAGER");

    address public Enforcer;
    // address public limitMarketContractAddress;
    address public BorrowRequestFactory;
    address public LendRequestFactory;
    address public TokenManager;
    uint256 public minimumDeposit;
    address public DEPLOYER;
    address public TOKEN_MANAGER_CONTRACT =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public LIMIT_MARKET_CONTRACT_ADDRESS;
    /// @dev listing fee to be paid by caller when creating a listing request.
    uint256 public constant LISTING_FEE = 1 ether;
    address public constant FEE_CONTRACT =
        0xDfCF9329f7cF00eC3A0a53109A1287C4d5A49C05;
    uint256 public constant MAX_ASSET_LIMIT = 6;
    uint256 public constant ORIGINATION_FEE = 6;
    uint256 public constant CANCELLATION_FEE = 10;
    uint256 public constant SETTLEMENT_FEE = 6;
    uint256 public constant INDEX_PRECISION = 1;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        _grantRole(MANAGER, msg.sender);
        console2.log("main", (address(this)));
        DEPLOYER = msg.sender;
        // console2.log(address(_protocolManager));
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

    function updateEnforcerContract(
        address _address
    ) external addressValidated(_address) onlyRole(MANAGER) {}
    function calculateTokenListingFee(
        address token
    ) external pure returns (uint256 fee) {
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
        console2.log("protocol manager deployer", DEPLOYER);
        LIMIT_MARKET_CONTRACT_ADDRESS = limitMarketAddress;
    }
    function updateBorrowRequestFactoryContract(
        address borrowRequestFactory
    ) external addressValidated(borrowRequestFactory) onlyRole(MANAGER) {
        BorrowRequestFactory = borrowRequestFactory;
    }
    function updateLendRequestFactoryContract(
        address _address
    ) external addressValidated(_address) onlyRole(MANAGER) {}
    function updateTokenManagerContract(
        address _address
    ) external addressValidated(_address) onlyRole(MANAGER) {}

    function calculateAmountMinus_OriginationFee(
        uint256 collateraValue
    ) external pure returns (uint256) {
        return (collateraValue - (calculateOriginationFee(collateraValue)));
    }

    function calculateAmountMinus_SettlementFee(
        uint256 collateraValue
    ) external pure returns (uint256) {
        return (collateraValue - (calculateSettlementFee(collateraValue))); // @note change magic number to precision constant
    }

    function calculateAmountMinus_CancellationFee(
        uint256 amount
    ) external pure returns (uint256) {
        return (amount - (calculateCancellationFee(amount)));
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC, INTERNAL & PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // @audit fix the fees
    function calculateCancellationFee(
        uint256 collateraValue
    ) private pure returns (uint256) {
        return ((collateraValue * CANCELLATION_FEE) / 100) * 1 ether;
    }
    function calculateOriginationFee(
        uint256 collateraValue
    ) private pure returns (uint256) {
        return ((collateraValue * ORIGINATION_FEE) / 100) * 1 ether;
    }

    // change to settlement fee
    function calculateSettlementFee(
        uint256 collateraValue
    ) private pure returns (uint256) {
        return (collateraValue * SETTLEMENT_FEE) / 100;
    }
}
