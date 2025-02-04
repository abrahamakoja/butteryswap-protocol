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
 * @author Abraham akoja
 * @notice
 */

// debug
import {Script, console} from "forge-std/Script.sol";

////////////////
/// Imports ///
//////////////

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {LendingRequest_v1} from "./LendingRequest_v1.sol";
import {ButteryRun_v1} from "./ButteryRun_v1.sol";
import {BorrowRequest_v1} from "./BorrowRequest_v1.sol";
import {erc20TokenLibrary} from "./erc20TokenLibrary.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

///////////////////
/// Interfaces ///
/////////////////

interface ISupportedTokens {
    function checkTokenIsApproved(address token) external view returns (bool);
}

// LimitMarket_v1 Contract Definition
contract LimitMarket_v1 is ReentrancyGuard, ButteryRun_v1, Ownable {
    ////////////////
    /// Errors ///
    //////////////

    error LimitMarket_v1_unSupportedToken(address token);
    // error LimitMarket_v1_NoCollateralSent(uint256 collateral);
    error LimitMarket_v1_TransferFailed(
        address borrowRequest,
        uint256 sentAmount
    );
    error LimitMarket_v1_InsufficientBalance(
        uint256 balance,
        uint256 collateral
    );
    error LimitMarket_v1_InvalidAmount(uint256 balance, uint256 amountSent);
    error LimitMarket_v1_NoAmountSent(uint256 balance, uint256 amountSent);
    error UnauthorizedAccess(address caller);
    // new
    error LimitMarket_v1_InvalidTokenCount(uint256 tokenCount);
    error LimitMarket_v1_NoCollateralSent(uint256 collateralAmount);
    error LimitMarket_v1_EnforcerNotInitialized();
    error LimitMarket_v1_InsufficientAllowance(
        address token,
        uint256 allowance,
        uint256 requiredAmount
    );

    /////////////////////////
    /// Type Declarations ///
    ///////////////////////

    using erc20TokenLibrary for erc20TokenLibrary.tokenData;

    /////////////////////////
    /// State variables ///
    ///////////////////////

    address private immutable i_admin;
    address private supportedTokensAddress;
    ISupportedTokens supportedTokensContract;
    LendingRequest_v1[] public totalLendRequestArray; //get this and only display the active
    BorrowRequest_v1[] public totalBorrowRequestArray;
    address private enforcerContract;
    mapping(address loanRequest => bool prioritized)
        private s_loanIsPrioritized;
    mapping(address => address[]) public userToBorrowRequestAddress;
    mapping(address => address[]) public userToLendRequestContracts;
    mapping(address lendrequest => uint256 positionOnQue)
        public lendRequestToPositionOnActiveRequestQue; // pending
    mapping(address borrowRequest => uint256 positionOnQue)
        private s_activeBorrowRequestOnQue; // pending
    mapping(address => uint256) private totalReceivedFromContracts;
    mapping(address => bool) private authorizedContracts;

    //////////////
    /// Events ///
    ////////////

    event BorrowRequestCreated(
        address indexed user,
        address indexed multiSigAddress,
        uint256 amountTransferred
    );

    event LendRequestCreated(
        address indexed user,
        address indexed multiSigAddress,
        uint256 amountLended
    );

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
        if (msg.sender != address(i_admin))
            revert UnauthorizedAccess(msg.sender);
        _;
    }

    //////////////////
    /// Functions ///
    ////////////////

    constructor() Ownable(msg.sender) {
        i_admin = msg.sender;
    }

    receive() external payable {}

    ////////////////////////
    ///External Functions ///
    ////////////////////////

//    new borrow
function borrow() external nonReentrant{
   
}

    // function borrow(
    //     uint256 collateralAmount,
    //     address[] calldata tokens,
    //     bool priority
    // ) external nonReentrant {
    //     // checks
    //     if (tokens.length == 0 || tokens.length > 3)
    //         revert LimitMarket_v1_InvalidTokenCount(tokens.length);
    //     if (collateralAmount == 0)
    //         revert LimitMarket_v1_NoCollateralSent(collateralAmount);
    //     if (address(enforcerContract) == address(0))
    //         revert LimitMarket_v1_EnforcerNotInitialized();

    //     for (uint256 index = 0; index < tokens.length; index++) {
            
    //         // ensure allowance is decrease when cancelled 
    //            erc20TokenLibrary.increaseAllowance( tokens[index],address(this),collateralAmount);
          
    //     }

    //     // effects
    //     address[2] memory owners = [msg.sender, address(enforcerContract)];
    //     BorrowRequest_v1 borrowRequest = new BorrowRequest_v1(
    //         owners,
    //         collateralAmount,
    //         tokens,
    //         block.timestamp
    //     );

    //     if (priority) {
    //         s_loanIsPrioritized[address(borrowRequest)] = true;
    //     }
    //     userToBorrowRequestAddress[msg.sender].push(address(borrowRequest));
    //     totalBorrowRequestArray.push(borrowRequest);

    //     // emits
    //     emit BorrowRequestCreated(
    //         msg.sender,
    //         address(borrowRequest),
    //         collateralAmount
    //     );
    //     emit TokensDeposited(msg.sender, tokens, collateralAmount);

    //     // interactions
    //     for (uint256 index = 0; index < tokens.length; index++) {
    //         erc20TokenLibrary.transferFromTokens(
    //             tokens[index],
    //             msg.sender,
    //             address(borrowRequest),
    //             collateralAmount
    //         );
    //     }
    // }

    function lend(bool priority) external payable nonReentrant {
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
        if (address(enforcerContract) == address(0)) revert();
        if (address(enforcerContract) != address(enforcerContract)) revert();
        // checks to add
        // msg.value should be equal or greater than dollar price of the minimum allowed amount

        // effects
        address[2] memory owners = [msg.sender, address(enforcerContract)];

        LendingRequest_v1 lendingRequest = new LendingRequest_v1(
            owners,
            msg.value
        );

        if (priority == true) {
            s_loanIsPrioritized[address(lendingRequest)] = true;
        }
        userToLendRequestContracts[msg.sender].push(address(lendingRequest));
        totalLendRequestArray.push(lendingRequest);

        // emits
        emit LendRequestCreated(msg.sender, address(lendingRequest), msg.value);

        //  interactions
        (bool success, ) = payable(lendingRequest).call{
            value: msg.value,
            gas: 2300
        }("");
        if (!success)
            revert LimitMarket_v1_TransferFailed(
                address(lendingRequest),
                msg.value
            );
    }

    // update enforcer contract
    function updateContracts(
        address enforcerAddress,
        address _supportedTokensAddress
    ) external onlyAdmin notUpdating {
        _setUpdating(UpdateState.UPDATING);
        enforcerContract = enforcerAddress;
        supportedTokensAddress = _supportedTokensAddress;
        supportedTokensContract = ISupportedTokens(supportedTokensAddress);
        _setUpdating(UpdateState.NOTUPDATING);
    }

    ////////////////////////
    /// Public Functions ///
    ////////////////////////

    function getEnforcerContractAddress()
        external
        view
        onlyAdmin
        returns (address)
    {
        return enforcerContract;
    }
    ////////////////////////
    /// Internal Functions ///
    ////////////////////////

    ////////////////////////
    /// Private Functions ///
    ////////////////////////

    ////////////////////////////////////////////////
    /// External & Public View & Pure Functions ///
    //////////////////////////////////////////////

    // **** borrow requests functions ****//

    // @dev returns the total active borrow requests addresses.
    function getTotalActiveBorrowRequestContractAddresses()
        public
        view
        returns (address[] memory)
    {
        address[] memory borrowRequest = new address[](
            totalBorrowRequestArray.length
        );
        uint256 counter = 0;
        for (uint256 i = 0; i < totalBorrowRequestArray.length; i++) {
            BorrowRequest_v1 borrowRequest_v1 = BorrowRequest_v1(
                payable(address(totalBorrowRequestArray[i]))
            );
            uint8 status = uint8(borrowRequest_v1.getRequestState());
            if (status != 0) {
                continue;
            }
            borrowRequest[counter] = address(totalBorrowRequestArray[i]);
            counter++;
        }

        address[] memory activeBorrowRequest = new address[](counter);
        for (uint256 i = 0; i < counter; i++) {
            activeBorrowRequest[i] = borrowRequest[i];
        }

        return activeBorrowRequest;
    }

    // @dev returns the specific index of an active borrow requests within the array of active borrow request.
    function getBorrowRequestPositionOnActiveRequestQue(
        address borrowRequest
    ) public view returns (uint256 position) {
        address[]
            memory borrowRequests = getTotalActiveBorrowRequestContractAddresses();
        for (uint256 i = 0; i < borrowRequests.length; i++) {
            if (borrowRequests[i] == address(borrowRequest)) {
                position = i + 1;
            }
        }
        return position;
    }

    // @dev returns the specific index of an active borrow requests within the array of active borrow request.
    function getActiveBorrowRequestContractAddressViaIndex(
        uint256 index
    ) public view returns (address borrowRequest) {
        address[]
            memory borrowRequests = getTotalActiveBorrowRequestContractAddresses();
        address targetBorrowRequestContract;
        for (uint256 i = 0; i < borrowRequests.length; i++) {
            if (borrowRequests[i] == borrowRequests[index]) {
                targetBorrowRequestContract = address(borrowRequests[i]);
            }
        }
        return targetBorrowRequestContract;
    }

    // returns specific number of requests using a start index and a number of requested contracts
    function getActiveBorrowRequestViaLimit(
        uint256 startIndex,
        uint256 requestedNumber
    ) external view returns (address[] memory borrowRequests) {
        address[]
            memory borrowRequest = getTotalActiveBorrowRequestContractAddresses();
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
        address[]
            memory borrowRequests = getTotalActiveBorrowRequestContractAddresses();
        return borrowRequests.length;
    }

    function getPrioritizedBorrowRequestAddress()
        external
        view
        returns (address loanRequest)
    {
        address[]
            memory borrowRequests = getTotalActiveBorrowRequestContractAddresses();
        for (uint256 i = 0; i < borrowRequests.length; i++) {
            if (s_loanIsPrioritized[borrowRequests[i]]) {
                loanRequest = address(borrowRequests[i]);
            }
        }
        return loanRequest;
    }

    // Function to retrieve all borrow request contracts for a user // legacy
    function getUserToBorrowRequestAddresses(
        address user
    ) external view returns (address[] memory) {
        return userToBorrowRequestAddress[user];
    }

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
            LendingRequest_v1 lendingRequest_v1 = LendingRequest_v1(
                payable(address(totalLendRequestArray[i]))
            );
            uint8 status = uint8(lendingRequest_v1.getRequestState());
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
