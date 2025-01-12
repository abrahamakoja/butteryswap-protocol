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
// import {Script, console} from "forge-std/Script.sol";

////////////////
/// Imports ///
//////////////

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {LendingRequest_v1} from "./LendingRequest_v1.sol";
import {ButteryRun_v1} from "./ButteryRun_v1.sol";
import {BorrowRequest_v1} from "./BorrowRequest_v1.sol";
import {erc20TokenLibrary} from "./erc20TokenLibrary.sol";


    //////////////////
    /// Interface ///
    ////////////////

    interface ISupportedTokens {
         function checkTokenIsApproved(address token) external view returns (bool);
    }

// Contract Definition
contract LimitMarket_v1 is ReentrancyGuard, ButteryRun_v1 {

    using erc20TokenLibrary for erc20TokenLibrary.tokenData;

    ////////////////
    /// Errors ///
    //////////////

    error LimitMarket__unSupportedToken(address token);
    error NoCollateralSent(uint256 collateral);
    error TransferFailed(address borrowRequest, uint256 sentAmount);
    error InsufficientBalance(uint256 balance, uint256 collateral);
    error InvalidAmount(uint256 balance, uint256 amountSent);
    error NoAmountSent(uint256 balance, uint256 amountSent);

    /////////////////////////
    /// Type Declarations ///
    ///////////////////////

    /////////////////////////
    /// State variables ///
    ///////////////////////


    address private supportedTokensAddress;
    ISupportedTokens supportedTokensContract;
    LendingRequest_v1[] public totalActiveLendRequestArray;//get this and only display the active
    BorrowRequest_v1[] public totalActiveBorrowRequestArray;
    address private enforcerContract;
    mapping(address => address[]) public userToBorrowRequestAddress;
    mapping(address => address[]) public userToLendRequestContracts;
    mapping(address lendrequest => uint256 positionOnQue) public lendRequestToPositionOnActiveRequestQue;// pending
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
        address tokenAddress,
        uint256 amount
    );

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
        // checks
        if (collateralAmount == 0) revert NoCollateralSent(collateralAmount);
        if (!supportedTokensContract.checkTokenIsApproved(address(token))) revert LimitMarket__unSupportedToken(token);
         if (address(enforcerContract) == address(0)) revert();
        if (address(enforcerContract) != address(enforcerContract)) revert();
        // checks to add
        // check if collateral amount is greater or equal to dollar minimum allowed value
        // check token address is valid erc20 within supportedTokens contract

        // effects
        address[2] memory owners = [
            msg.sender,
            address(enforcerContract)
        ];

        BorrowRequest_v1 borrowRequest = new BorrowRequest_v1(
            owners,
            collateralAmount,
            address(token)
        );
        // authorizedContracts[address(borrowRequest)] = true;
        userToBorrowRequestAddress[msg.sender].push(address(borrowRequest));
        totalActiveBorrowRequestArray.push(borrowRequest);
        
        // emits
        emit BorrowRequestCreated(msg.sender, address(token), collateralAmount);
        emit TokensDeposited(msg.sender, address(token), collateralAmount); 

        // interactions
     erc20TokenLibrary.transferFromTokens(
            address(token),
            msg.sender,
            address(borrowRequest),
            collateralAmount
        );
    }

   
    function lend() external payable nonReentrant {

        // checks
        if (msg.value == 0) revert NoAmountSent(msg.sender.balance, msg.value);
        if (msg.value > msg.sender.balance) revert InvalidAmount(msg.sender.balance, msg.value);
        if (msg.value >= msg.sender.balance) revert InsufficientBalance(msg.sender.balance, msg.value);
        if (address(enforcerContract) == address(0)) revert();
        if (address(enforcerContract) != address(enforcerContract)) revert();
        // checks to add
        // msg.value should be equal or greater than dollar price of the minimum allowed amount

        // effects
        address[2] memory owners = [
            msg.sender,
            address(enforcerContract)
        ];
        
        LendingRequest_v1 lendingRequest = new LendingRequest_v1(
            owners,
            msg.value
        );
         
        userToLendRequestContracts[msg.sender].push(address(lendingRequest));
        totalActiveLendRequestArray.push(lendingRequest);
    
        // emits
        emit LendRequestCreated(msg.sender, address(lendingRequest),  msg.value);
        
        //  interactions
        (bool success, ) = payable(lendingRequest).call{value: msg.value, gas: 2300}("");
        if (!success) revert TransferFailed(address(lendingRequest), msg.value);

    }

    // update enforcer contract    
    function updateContracts(
        address enforcerAddress,
        address _supportedTokensAddress    
    ) external onlyOwner notUpdating {
        _setUpdating(UpdateState.UPDATING);
        enforcerContract = enforcerAddress;
        supportedTokensAddress = _supportedTokensAddress;
        supportedTokensContract = ISupportedTokens(supportedTokensAddress);
        _setUpdating(UpdateState.NOTUPDATING);
    }

    function getEnforcerContractAddress() public view onlyOwner returns (address) {
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
        return userToLendRequestContracts[user];
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
  function getLendRequestPositionOnActiveRequestQue(address lendRequest) public view returns(uint256 position){
     address[] memory lendRequests = getTotalActiveLendRequestArray();
     for (uint256 i = 0; i < lendRequests.length; i++) 
     {
        if (lendRequests[i] == address(lendRequest)) {
            
            position = i + 1;
        }
     }
     return  position;
  }
    function getTotalActiveLendRequestArray()
        public
        view
        returns (address[] memory)
    {
        address[] memory lendRequest = new address[](totalActiveLendRequestArray.length);
        uint256 counter = 0;
        for (uint256 i = 0; i < totalActiveLendRequestArray.length; i++) {
            LendingRequest_v1 lendingRequest_v1 = LendingRequest_v1(payable(address(totalActiveLendRequestArray[i])));
            // uint8 status = uint8(lendingRequest_v1.getRequestState());
            if (uint8(lendingRequest_v1.getRequestState()) != 0 ) { 
            continue;
            }
             lendRequest[counter] = address(totalActiveLendRequestArray[i]);
             counter++;
        }

         address[] memory activeLendRequest = new address[](counter);
         for (uint256 i=0 ; i < counter; i++) 
         {
            activeLendRequest[i] = lendRequest[i];
         }
      
        return activeLendRequest;
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
