// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*//////////////////////////////////////////////////////////////
                                 IMPORTS
    //////////////////////////////////////////////////////////////*/

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ProtocolManager is Ownable {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ProtocolManager__invalidAddress();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address public Enforcer;
    address public LimitMarket;
    address public BorrowRequestFactory;
    address public LendRequestFactory;
    address public TokenManager;
    uint256 public  minimumDeposit;
     /// @dev listing fee to be paid by caller when creating a listing request.
    uint256 public constant  LISTING_FEE = 1 ether;
    address public constant FEE_CONTRACT =
        0xDfCF9329f7cF00eC3A0a53109A1287C4d5A49C05;
    uint256 public constant ORIGINATION_FEE = 6;
    uint256 public constant CANCELLATION_FEE = 10;
    uint256 public constant SETTLEMENT_FEE = 6;

    constructor() Ownable(msg.sender) {}

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
    ) external addressValidated(_address) onlyOwner {}
    function updateLimitMarketContract(
        address _address
    ) external addressValidated(_address) onlyOwner {}
    function updateBorrowRequestFactoryContract(
        address _address
    ) external addressValidated(_address) onlyOwner {}
    function updateLendRequestFactoryContract(
        address _address
    ) external addressValidated(_address) onlyOwner {}
    function updateTokenManagerContract(
        address _address
    ) external addressValidated(_address) onlyOwner {}

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
