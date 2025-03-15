// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title LimitMarket_v1
 * @author ButterySwap Protocol
 * @notice
 */

// debug
import {Script, console} from "forge-std/Script.sol";

////////////////
/// Imports ///
//////////////

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {LendRequest_v1} from "./LendRequest_v1.sol";
import {ButteryRun_v1} from "./ButteryRun_v1.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

///////////////////
/// Interfaces ///
/////////////////

interface IBorrowRequestFactory {
    function getTotalActiveBorrowRequestContractCount()
        external
        view
        returns (uint256 numberOfContracts);
    function getBorrowRequestPositionOnActiveRequestQue(
        address borrowRequest
    ) external view returns (uint256 position);

    function getTotalActivePrioritizedBorrowRequests(
        uint256 _batchLimit,
        uint256 numOfResponse
    ) external view returns (address[] memory);

    function getBatchedActiveBorrowRequestContractAddresses(
        uint256 startIndex,
        uint256 numberOfResponse,
        uint256 _batchLimit
    ) external view returns (address[] memory);

   function createBorrowRequest(
        uint256 _collateralAmount,
        uint256 _loanAmountRequested,
        address[] calldata _tokens,
        address[2] calldata _owners,
        bool _priority
    ) external ;
}

interface ILendRequestFactory {
    function getTotalActiveLendRequestContractCount()
        external
        view
        returns (uint256 numberOfContracts);
        function getLendRequestPositionOnActiveRequestQue(
        address lendRequest
    ) external view returns (uint256 position);
    function getBatchedActiveLendRequestAddresses(
        uint256 startIndex,
        uint256 numberOfResponse,
        uint256 _batchLimit
    ) external view returns (address[] memory);
    function getTotalActivePrioritizedLendRequests(
        uint256 _batchLimit,
        uint256 numOfResponse
    ) external view returns (address[] memory);
    function createLendRequest(
        address[2] calldata _owners,
        bool _priority
    ) external;
}

// LimitMarket_v1 Contract Definition
contract LimitMarket_v1 is ReentrancyGuard, ButteryRun_v1, Ownable {
    ////////////////
    /// Errors ///
    //////////////

    error UnauthorizedAccess(address caller);
    // new
    error LimitMarket_v1_InvalidTokenCount(uint256 tokenCount);
    error LimitMarket_v1_NoCollateralSent(uint256 collateralAmount);
    error LimitMarket_v1_EnforcerNotInitialized();
    error LimitMarket_v1_NoAmountSent(uint256 balance, uint256 amountSent);
    error LimitMarket_v1_InvalidAmount(uint256 balance, uint256 amountSent);
    error LimitMarket_v1_InsufficientBalance(
        uint256 balance,
        uint256 collateral
    );

    /////////////////////////
    /// Type Declarations ///
    ///////////////////////

    /////////////////////////
    /// State variables ///
    ///////////////////////

    address private immutable i_Admin;
    IBorrowRequestFactory i_BorrowRequestFactory;
    ILendRequestFactory i_LendRequestFactory;
    address private enforcerContract;

    //////////////
    /// Events ///
    /////////////

    event TokensDeposited(
        address indexed user,
        address[] tokenAddress,
        uint256 amount
    );

    //////////////////
    /// Modifiers ////
    ////////////////

    modifier enforcerContractIsSet() {
        if (address(enforcerContract) == address(0)) revert(); //prevent function from running if enforcer isnt set, move this to a modifier
        if (address(enforcerContract) != address(enforcerContract)) revert();
        _;
    }

    modifier onlyAdmin() {
        if (msg.sender != address(i_Admin))
            revert UnauthorizedAccess(msg.sender);
        _;
    }

    //////////////////
    /// Functions ///
    ////////////////

    constructor(
        address BorrowRequestFactory,
        address LendRequestFactory
    ) Ownable(msg.sender) {
        i_BorrowRequestFactory = IBorrowRequestFactory(BorrowRequestFactory);
        i_LendRequestFactory = ILendRequestFactory(LendRequestFactory);
        i_Admin = msg.sender;
    }

    // receive() external payable {}

    ////////////////////////
    ///External Functions ///
    ////////////////////////

    /// @notice Internal function to create a new BorrowRequest instance
    /// @param collateralAmount The amount of collateral to be locked
    /// @param tokens The list of tokens to be used as collateral
    function Borrow(
        uint256 collateralAmount,
        uint256 loanAmountRequested,
        address[] calldata tokens,
        bool priority
    ) external payable nonReentrant enforcerContractIsSet {
        // checks
        if (tokens.length == 0 || tokens.length > 3)
            revert LimitMarket_v1_InvalidTokenCount(tokens.length);
        if (collateralAmount == 0)
            revert LimitMarket_v1_NoCollateralSent(collateralAmount);

        address[2] memory owners = [msg.sender, address(enforcerContract)];

        // emits 
        emit TokensDeposited(msg.sender, tokens, collateralAmount);
        i_BorrowRequestFactory.createBorrowRequest(
            collateralAmount,
            loanAmountRequested,
            tokens,
            owners, 
            priority
        );
    }

    function Lend(
        bool _priority
    ) external payable nonReentrant enforcerContractIsSet {
        // checks
        if (msg.value == 0)
            revert LimitMarket_v1_NoAmountSent(msg.sender.balance, msg.value);
        if (msg.value > msg.sender.balance)
            revert LimitMarket_v1_InvalidAmount(msg.sender.balance, msg.value);
        if (msg.value >= msg.sender.balance)
            revert LimitMarket_v1_InsufficientBalance(
                msg.sender.balance,
                msg.value
            );

        // checks to add
        // msg.value should be equal or greater than dollar price of the minimum allowed amount
        address[2] memory owners = [msg.sender, address(enforcerContract)];
        i_LendRequestFactory.createLendRequest(owners, _priority);
    }

    // update enforcer contract
    function updateContracts(
        address _enforcerAddress,
        address _BorrowRequestFactory,
        address _LendRequestFactory
    ) external onlyAdmin notUpdating {
        _setUpdating(UpdateState.UPDATING);
        enforcerContract = _enforcerAddress;
        i_BorrowRequestFactory = IBorrowRequestFactory(_BorrowRequestFactory);
        i_LendRequestFactory = ILendRequestFactory(_LendRequestFactory);
        _setUpdating(UpdateState.NOTUPDATING);
    }

    ////////////////////////
    /// Public Functions ///
    ////////////////////////

    ////////////////////////
    /// Internal Functions ///
    ////////////////////////

    ////////////////////////
    /// Private Functions ///
    ////////////////////////

    ////////////////////////////////////////////////
    /// External & Public View & Pure Functions ///
    //////////////////////////////////////////////

    function getEnforcerContractAddress()
        external
        view
        onlyAdmin
        returns (address)
    {
        return enforcerContract;
    }

    // **** borrow requests functions ****//

    function getBorrowersPositionOnQue(
        address borrowRequest
    ) external view returns (uint256 position) {
        return
            i_BorrowRequestFactory.getBorrowRequestPositionOnActiveRequestQue(
                borrowRequest
            );
    }

    // returns specific number of requests using a start index and a number of requested contracts
    function getActiveBorrowRequestViaLimit(
        uint256 _startIndex,
        uint256 _numberOfResponse,
        uint256 _batchLimit
    ) external view returns (address[] memory borrowRequests) {
        return
            i_BorrowRequestFactory
                .getBatchedActiveBorrowRequestContractAddresses(
                    _startIndex,
                    _numberOfResponse,
                    _batchLimit
                );
    }

    // @dev returns the total active borrow requests count.
    function getTotalActiveBorrowRequestContractCount()
        external
        view
        returns (uint256 numberOfContracts)
    {
        return
            i_BorrowRequestFactory.getTotalActiveBorrowRequestContractCount();
    }

    // @dev returns the total active borrow requests prioritized addresses.
    function getPrioritizedBorrowRequestAddress(
        uint256 batchLimit,
        uint256 numOfResponse
    ) external view returns (address[] memory prioritizedLoans) {
        return
            i_BorrowRequestFactory.getTotalActivePrioritizedBorrowRequests(
                batchLimit,
                numOfResponse
            );
    }

    // **** lend requests functions ****//

     function getLendersPositionOnQue(
        address lendRequest
    ) external view returns (uint256 position) {
        return
            i_LendRequestFactory.getLendRequestPositionOnActiveRequestQue(
                lendRequest
            );
    }

    function getPrioritizedLendRequestAddress(
        uint256 batchLimit,
        uint256 numOfResponse
    ) external view returns (address[] memory prioritizedLoans) {
        return
            i_LendRequestFactory.getTotalActivePrioritizedLendRequests(
                batchLimit,
                numOfResponse
            );
    }

    // @dev returns the total active lend requests count.
    function getTotalActiveLendRequestContractCount()
        external
        view
        returns (uint256 count)
    {
        return i_LendRequestFactory.getTotalActiveLendRequestContractCount();
    }

    // returns specific number of requests using a start index and a number of requested contracts
    function getActiveLendRequestViaLimit(
        uint256 _startIndex,
        uint256 _numberOfResponse,
        uint256 _batchLimit
    ) external view returns (address[] memory lendRequests) {
        return
            i_LendRequestFactory.getBatchedActiveLendRequestAddresses(
                _startIndex,
                _numberOfResponse,
                _batchLimit
            );
    }

    
}
