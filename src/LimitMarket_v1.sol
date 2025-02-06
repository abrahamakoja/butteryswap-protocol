// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

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
// import {erc20TokenLibrary} from "./erc20TokenLibrary.sol";

///////////////////
/// Interfaces ///
/////////////////

interface IBorrowRequestFactory {
    function getTotalActiveBorrowRequestContractAddresses()
        external
        view
        returns (address[] memory);

    function createBorrowRequest(
        uint256 _collateralAmount,
        address[] calldata _tokens,
        address[2] calldata _owners,
        bool _priority
    ) external;
}

// LimitMarket_v1 Contract Definition
contract LimitMarket_v1 is ReentrancyGuard, ButteryRun_v1, Ownable {
    ////////////////
    /// Errors ///
    //////////////

    // error LimitMarket_v1_TransferFailed(
    //     address borrowRequest,
    //     uint256 sentAmount
    // );
    // error LimitMarket_v1_InsufficientBalance(
    //     uint256 balance,
    //     uint256 collateral
    // );
    // error LimitMarket_v1_InvalidAmount(uint256 balance, uint256 amountSent);
    // error LimitMarket_v1_NoAmountSent(uint256 balance, uint256 amountSent);
    error UnauthorizedAccess(address caller);
    // new
    error LimitMarket_v1_InvalidTokenCount(uint256 tokenCount);
    error LimitMarket_v1_NoCollateralSent(uint256 collateralAmount);
    error LimitMarket_v1_EnforcerNotInitialized();

    /////////////////////////
    /// Type Declarations ///
    ///////////////////////

    // using erc20TokenLibrary for erc20TokenLibrary.tokenData;

    /////////////////////////
    /// State variables ///
    ///////////////////////

    address private immutable i_Admin;
    IBorrowRequestFactory i_BorrowRequestFactory;
    // ISupportedTokens supportedTokensContract;
    // LendRequest_v1[] public totalLendRequestArray; //get this and only display the active
    // BorrowRequest_v1[] public totalBorrowRequestArray;
    address private enforcerContract;
    // mapping(address loanRequest => bool prioritized)
    //     private s_loanIsPrioritized;
    // mapping(address => address[]) public userToLendRequestContracts;

    //////////////
    /// Events ///
    ////////////

    // event LendRequestCreated(
    //     address indexed user,
    //     address indexed multiSigAddress,
    //     uint256 amountLended
    // );

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

    constructor(address BorrowRequestFactory) Ownable(msg.sender) {
        i_BorrowRequestFactory = IBorrowRequestFactory(BorrowRequestFactory);
        i_Admin = msg.sender;
    }

    receive() external payable {}

    ////////////////////////
    ///External Functions ///
    ////////////////////////

    /// @notice Internal function to create a new BorrowRequest instance
    /// @param collateralAmount The amount of collateral to be locked
    /// @param tokens The list of tokens to be used as collateral
    function Borrow(
        uint256 collateralAmount,
        address[] calldata tokens,
        bool priority
    ) external nonReentrant enforcerContractIsSet {
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
            tokens,
            owners,
            priority
        );
    }

    // function lend(bool priority) external payable nonReentrant {
    //     // checks
    //     if (msg.value == 0)
    //         revert LimitMarket_v1_NoAmountSent(msg.sender.balance, msg.value);
    //     if (msg.value > msg.sender.balance)
    //         revert LimitMarket_v1_InvalidAmount(msg.sender.balance, msg.value);
    //     if (msg.value >= msg.sender.balance)
    //         revert LimitMarket_v1_InsufficientBalance(
    //             msg.sender.balance,
    //             msg.value
    //         );
    //     if (address(enforcerContract) == address(0)) revert();
    //     if (address(enforcerContract) != address(enforcerContract)) revert();
    //     // checks to add
    //     // msg.value should be equal or greater than dollar price of the minimum allowed amount

    //     // effects
    //     address[2] memory owners = [msg.sender, address(enforcerContract)];

    //     LendRequest_v1 lendRequest = new LendRequest_v1(
    //         owners,
    //         msg.value
    //     );

    //     if (priority == true) {
    //         s_loanIsPrioritized[address(lendRequest)] = true;
    //     }
    //     userToLendRequestContracts[msg.sender].push(address(lendRequest));
    //     totalLendRequestArray.push(lendRequest);

    //     // emits
    //     emit LendRequestCreated(msg.sender, address(lendRequest), msg.value);

    //     //  interactions
    //     (bool success, ) = payable(lendRequest).call{
    //         value: msg.value,
    //         gas: 2300
    //     }("");
    //     if (!success)
    //         revert LimitMarket_v1_TransferFailed(
    //             address(lendRequest),
    //             msg.value
    //         );
    // }

    // update enforcer contract
    function updateContracts(
        address enforcerAddress,
        address _BorrowRequestFactory
    ) external onlyAdmin notUpdating {
        _setUpdating(UpdateState.UPDATING);
        enforcerContract = enforcerAddress;
        i_BorrowRequestFactory = IBorrowRequestFactory(_BorrowRequestFactory);
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

    // returns specific number of requests using a start index and a number of requested contracts
    function getActiveBorrowRequestViaLimit(
        uint256 startIndex,
        uint256 requestedNumber
    ) external view returns (address[] memory borrowRequests) {
        address[] memory borrowRequest = i_BorrowRequestFactory
            .getTotalActiveBorrowRequestContractAddresses();
        uint256 counter = 0;
        for (uint256 i = 0; i < borrowRequest.length; i++) {
            if (i < startIndex) {
                continue;
            } else if (i >= startIndex) {
                borrowRequest[counter] = address(borrowRequest[i]);
                if (counter >= requestedNumber) {
                    break;
                }
                counter++;
            }
        }
        address[] memory requestedBorrowRequest = new address[](counter);
        for (uint256 i = 0; i < counter; i++) {
            requestedBorrowRequest[i] = address(borrowRequest[i]);
        }
        return requestedBorrowRequest;
    }

    // @dev returns the total active borrow requests count.
    function getTotalActiveBorrowRequestContractCount()
        external
        view
        returns (uint256 count)
    {
        address[] memory borrowRequests = i_BorrowRequestFactory
            .getTotalActiveBorrowRequestContractAddresses();
        return borrowRequests.length;
    }

    // @dev returns the total active borrow requests prioritized addresses.
    function getPrioritizedBorrowRequestAddress()
        external
        view
        returns (address loanRequest)
    {
        address[] memory borrowRequests = i_BorrowRequestFactory
            .getTotalActiveBorrowRequestContractAddresses();
        for (uint256 i = 0; i < borrowRequests.length; i++) {
            if (s_loanIsPrioritized[borrowRequests[i]]) {
                loanRequest = address(borrowRequests[i]);
            }
        }
        return loanRequest;
    }

    // ************************
    // **** lend requests functions ****//

    function getPrioritizedLendRequestAddress()
        external
        view
        returns (address loanRequest)
    {
        address[]
            memory lendRequests = getTotalActiveLendRequestContractAddresses();
        for (uint256 i = 0; i < lendRequests.length; i++) {
            if (s_loanIsPrioritized[lendRequests[i]]) {
                loanRequest = address(lendRequests[i]);
            }
        }
        return loanRequest;
    }

    function getTotalActiveLendRequestContractAddresses()
        public
        view
        returns (address[] memory)
    {
        address[] memory lendRequest = new address[](
            totalLendRequestArray.length
        );
        uint256 counter = 0;
        for (uint256 i = 0; i < totalLendRequestArray.length; i++) {
            LendRequest_v1 lendRequest_v1 = LendRequest_v1(
                payable(address(totalLendRequestArray[i]))
            );
            uint8 status = uint8(lendRequest_v1.getRequestState());
            if (status != 0) {
                continue;
            }
            lendRequest[counter] = address(totalLendRequestArray[i]);
            counter++;
        }

        address[] memory activeLendRequest = new address[](counter);
        for (uint256 i = 0; i < counter; i++) {
            activeLendRequest[i] = lendRequest[i];
        }

        return activeLendRequest;
    }

    function getLendRequestPositionOnActiveRequestQue(
        address lendRequest
    ) external view returns (uint256 position) {
        address[]
            memory lendRequests = getTotalActiveLendRequestContractAddresses();
        for (uint256 i = 0; i < lendRequests.length; i++) {
            if (lendRequests[i] == address(lendRequest)) {
                position = i + 1;
            }
        }
        return position;
    }

    // @dev returns the specific index of an active borrow requests within the array of active borrow request.
    function getActiveLendRequestContractAddressViaIndex(
        uint256 index
    ) external view returns (address borrowRequest) {
        address[]
            memory lendRequests = getTotalActiveLendRequestContractAddresses();
        address targetLendRequestContract;
        for (uint256 i = 0; i < lendRequests.length; i++) {
            if (lendRequests[i] == lendRequests[index]) {
                targetLendRequestContract = address(lendRequests[i]);
            }
        }
        return targetLendRequestContract;
    }

    // @dev returns the total active borrow requests count.
    function getTotalActiveLendRequestContractCount()
        external
        view
        returns (uint256 count)
    {
        address[]
            memory lendRequests = getTotalActiveLendRequestContractAddresses();
        return lendRequests.length;
    }

    // returns specific number of requests using a start index and a number of requested contracts
    function getActiveLendRequestViaLimit(
        uint256 startIndex,
        uint256 requestedNumber
    ) external view returns (address[] memory lendRequests) {
        address[]
            memory lendRequest = getTotalActiveLendRequestContractAddresses();
        uint256 counter = 0;
        for (uint256 i = 0; i < lendRequest.length; i++) {
            if (i < startIndex) {
                continue;
            } else if (i >= startIndex) {
                lendRequest[counter] = address(lendRequest[i]);
                if (counter >= requestedNumber) {
                    break;
                }
                counter++;
            }
        }
        address[] memory requestedLendRequest = new address[](counter);
        for (uint256 i = 0; i < counter; i++) {
            requestedLendRequest[i] = address(lendRequest[i]);
        }
        return requestedLendRequest;
    }

    function getUserToLendRequestAddresses(
        address user
    ) external view returns (address[] memory) {
        return userToLendRequestContracts[user];
    }
}
