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
import {CreateLendingRequest_v1} from "./CreateLendingRequest_v1.sol";
import {ButteryRun_v1} from "./ButteryRun_v1.sol";
import {CreateBorrowRequest_v1} from "./CreateBorrowRequest_v1.sol";
import {SupportedTokens} from "./SupportedTokens.sol";
import {erc20TokenLibrary} from "./erc20TokenLibrary.sol";

// Contract Definition
contract LimitMarket_v1 is ReentrancyGuard, ButteryRun_v1 {
    using erc20TokenLibrary for erc20TokenLibrary.tokenData;

    ////////////////
    /// Errors ///
    //////////////

    error LimitMarket__borrowFailed(address token);
    error NoCollateralSent(uint256 collateral);
    error TransferFailed(address borrowRequest, uint256 sentAmount);
    error InsufficientBalance(uint256 balance, uint256 collateral);
    error InvalidAmount(uint256 balance, uint256 amountSent);
    error NoAmountSent(uint256 balance, uint256 amountSent);
    // error InvalidInterestRate(uint256 interestRate);
    // error ERC20InsufficientAllowance(
    //     address spender,
    //     uint256 allowance,
    //     uint256 required
    // );
    // error InvalidWithdrawalAmount(
    //     uint256 requestedAmount,
    //     uint256 availableBalance
    // );

    /////////////////////////
    /// Type Declarations ///
    ///////////////////////

    /////////////////////////
    /// State variables ///
    ///////////////////////

    uint256 public totalBorrowersCount;
    uint256 private totalFeesEarned;
    uint256 public totalLendersCount;
    SupportedTokens supportedTokens;
    CreateLendingRequest_v1[] public totalActiveLendRequestArray;
    CreateBorrowRequest_v1[] public totalActiveBorrowRequestArray;
    address private enforcerContract;
    // address[] private totalActiveBorrowRequestArray;
    address[] private protocolUsers; //not used yet
    // mapping(address => BorrowRequestDetails) private userToBorrowRequestDetails;
    // mapping(address => LendRequestDetails) private userToLendRequestDetails;
    mapping(address => address[]) public userToBorrowRequestAddress;
    mapping(address => address[]) public userLendRequestAddress;
    mapping(address => uint256) private totalFeesEarnedOnLendRequests;
    mapping(address => uint256) private totalReceivedFromContracts;
    mapping(address => bool) private authorizedContracts;

    //////////////
    /// Events ///
    ////////////

    event MultiSigCreated(
        address indexed user,
        address indexed multiSigAddress,
        uint256 amountTransferred
    );
    event ContractFunded(address contractAddress, uint256 amount);
    event MultiSigDetailsUpdated(
        address indexed multiSigAddress,
        uint256 amountLended,
        uint256 amountToReceive
    );
    event FeeWithdrawn(uint256 amount, address indexed receiver);
    event TokensDeposited(
        address indexed user,
        address tokenAddress,
        uint256 amount
    );
    event TokensWithdrawn(
        address indexed user,
        address indexed tokenAddress,
        uint256 amount
    );
    event debug(bool);

    //////////////////
    /// Modifiers ////
    ////////////////

    ////////////////
    /// Functions ///
    //////////////

    constructor() {}

    receive() external payable /*onlyDeployedContracts*/ {
        totalReceivedFromContracts[msg.sender] += msg.value;
    }

    ////////////////////////
    ///External Functions ///
    ////////////////////////

    function borrow(
        uint256 collateralAmount,
        address token
    ) external nonReentrant {
        if (collateralAmount == 0) revert NoCollateralSent(collateralAmount);
        // console.log(supportedTokens.checkTokenIsApproved(address(token)));
        // if (!supportedTokens.checkTokenIsApproved(address(token))) revert LimitMarket__borrowFailed(token);

        address[3] memory owners = [
            msg.sender,
            address(this), 
            address(enforcerContract)
        ];
        CreateBorrowRequest_v1 borrowRequest = new CreateBorrowRequest_v1(
            owners,
            collateralAmount,
            address(token)
        );
        // emit debug(supportedTokens.checkTokenIsApproved(address(token)));
        emit MultiSigCreated(msg.sender, address(token), collateralAmount);
        emit TokensDeposited(msg.sender, address(token), collateralAmount); // Emit token deposit event
        userToBorrowRequestAddress[msg.sender].push(address(borrowRequest));
        totalActiveBorrowRequestArray.push(borrowRequest);
        totalBorrowersCount++;
        erc20TokenLibrary.transferFromTokens(
            address(token),
            msg.sender,
            address(borrowRequest),
            collateralAmount
        );
    }

    // Function to create a multisig contract for lending
    function Lend() external payable nonReentrant {
        // check value
        if (msg.value == 0) revert NoAmountSent(msg.sender.balance, msg.value);
        if (msg.value > msg.sender.balance)
            revert InvalidAmount(msg.sender.balance, msg.value);
        if (msg.value >= msg.sender.balance)
            revert InsufficientBalance(msg.sender.balance, msg.value);

        // check addresses
        if (address(msg.sender) == address(0)) revert();
        if (address(msg.sender) != address(msg.sender)) revert();
        if (address(this) == address(0)) revert();
        if (address(this) != address(this)) revert();
        if (address(enforcerContract) == address(0)) revert();
        if (address(enforcerContract) != address(enforcerContract)) revert();
        if (address(msg.sender) == address(0)) revert();

        address[3] memory owners = [
            msg.sender,
            address(this),
            address(enforcerContract)
        ];
        uint256 amountSent = msg.value;
        CreateLendingRequest_v1 lendingRequest = new CreateLendingRequest_v1(
            owners,
            amountSent
        );

        emit MultiSigCreated(msg.sender, address(lendingRequest), amountSent);
        emit ContractFunded(address(lendingRequest), amountSent);

        // Transfer Ether to multisig
        totalLendersCount++;
        authorizedContracts[address(lendingRequest)] = true;
        totalActiveLendRequestArray.push(lendingRequest);
        userLendRequestAddress[msg.sender].push(address(lendingRequest));
        _transferToMultiSig(address(lendingRequest), amountSent);
    }

    // update enforcer contract
    function updateContracts(
        address enforcerAddress
    ) external onlyOwner notUpdating {
        _setUpdating(UpdateState.UPDATING);
        enforcerContract = enforcerAddress;
        _setUpdating(UpdateState.NOTUPDATING);
    }

    function getEnforcerContractAddress() public view returns (address) {
        return enforcerContract;
    }

    // Add this function to your LimitMarket_v1 contract
    function getTotalActiveBorrowRequestArray()
        public
        view
        returns (address[] memory)
    {
        address[] memory borrowRequests = new address[](
            totalActiveBorrowRequestArray.length
        );
        for (uint256 i = 0; i < totalActiveBorrowRequestArray.length; i++) {
            borrowRequests[i] = address(totalActiveBorrowRequestArray[i]);
        }
        return borrowRequests;
    }

    ////////////////////////
    /// Public Functions ///
    ////////////////////////

    function getUserToLendRequestAddresses(
        address user
    ) public view returns (address[] memory) {
        return userLendRequestAddress[user];
    }

    // Function to retrieve all borrow request contracts for a user
    function getUserToBorrowRequestAddresses(
        address user
    ) public view returns (address[] memory) {
        return userToBorrowRequestAddress[user];
    }

    // Function to get total fees of a specific lending request contract
    function getTotalFeesEarnedOnLendRequests(
        address contractAddress
    ) public view onlyOwner returns (uint256) {
        return totalReceivedFromContracts[contractAddress];
    }

    function getTotalActiveLendRequestArray()
        public
        view
        returns (address[] memory)
    {
        address[] memory lendRequest = new address[](
            totalActiveLendRequestArray.length
        );
        for (uint256 i = 0; i < totalActiveLendRequestArray.length; i++) {
            lendRequest[i] = address(totalActiveLendRequestArray[i]);
        }
        return lendRequest;
    }

    ////////////////////////
    /// Internal Functions ///
    ////////////////////////

   
    function _transferToMultiSig(
        address contractAddress,
        uint256 amount
    ) internal  {
        (bool success, ) = payable(contractAddress).call{value: amount, gas: 2300}(
            ""
        );
        if (!success) revert TransferFailed(contractAddress, amount);
    }

    ////////////////////////
    /// Private Functions ///
    ////////////////////////
}
