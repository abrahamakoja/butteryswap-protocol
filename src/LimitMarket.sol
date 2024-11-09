// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Imports
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {CreateMultiSig} from "./CreateMultiSig.sol";

// Errors
error NoCollateralSent(uint256);
error TransferFailed(address borrowrequest, uint256 sentAmount);
error OnlyOwnerAllowed();
error InsufficientBalance(uint256 balance, uint256 collateral);
error inValidAmount(uint256 balance, uint256 amountsent);
error NoAmountSent(uint256 balance, uint256 amountsent);

// Type Declarations
struct borrowRequest {
    uint256 depositedAmount;
    uint256 collateral;
 uint256 position;
    // add balance of tokens, address and any value to be used
}

// Contract Definition
contract LimitMarket is ReentrancyGuard{
    using SafeERC20 for IERC20;

    // State Variables
    uint256 public totalBorrowersCount;
    address[] public protol_TotalActiveBorrowRequest_Array;//total active borrow requests contract address in the protocol
    address[] public protocolUsers;// list of all wallets interacting with buttery swap protocol || may move this smwhere else
    mapping(address => borrowRequest) public userToBorrowRequestDetails; //stores a mapping of a specific user wallet address to the struct borrow request.
    mapping(address => address[]) public userToBorrowRequestAddress; //stores a mapping of a specific user wallet address to all their borrow requests contract they made.
   
    // Events
    event MultiSigCreated(
        address indexed user,
        address indexed multiSigAddress,
        uint256 amountTransferred
    );
    event MultiSigDetailsUpdated(
        address indexed multiSigAddress,
        uint256 depositedAmount,
        uint256 amountToReceive
    );

    // Constructor
    constructor() {
    }

    // Function to create a multisig contract between this contract and the caller, and transfer Ether to the newly created multisig
    function createMultiSig(uint256 _collateral) external payable nonReentrant {
        // Check the amount to send is valid
        if (msg.value == 0) revert NoAmountSent(msg.sender.balance, msg.value);
        if (msg.value > msg.sender.balance) revert inValidAmount(msg.sender.balance, msg.value);
        if (_collateral == 0) revert NoCollateralSent(msg.value);
        if (_collateral >= msg.sender.balance) revert InsufficientBalance(msg.sender.balance, _collateral);
         
        address[2] memory owners =[msg.sender,address(this)];
        CreateMultiSig multiSig = new CreateMultiSig(owners);

          // withdraws memecoin amount
        //  // Transfer the Ether to the multisig contract
        (bool success, ) = payable(address(multiSig)).call{
            value: msg.value, gas: 2300
        }("");
        if (!success) revert TransferFailed(address(multiSig), msg.value);


        // // Emit events
        emit MultiSigCreated(msg.sender, address(multiSig), msg.value);
        emit MultiSigDetailsUpdated(address(multiSig), msg.value, _collateral);

             totalBorrowersCount++;
        //     // store values for borrow request parameters
            userToBorrowRequestDetails[address(multiSig)] = borrowRequest({
                depositedAmount: msg.value,
                collateral: _collateral,
                position: totalBorrowersCount
            });

        
        protol_TotalActiveBorrowRequest_Array.push(address(multiSig));
     userToBorrowRequestAddress[msg.sender].push(address(multiSig));
            // userToBorrowRequestAddress[msg.sender].push(address(multiSig));
    }

    // Function to retrieve all borrow request contracts for a user
    function getUserToBorrowRequest_Addresses(address user)
        external
        view
        returns (address[] memory)
    {      
        return userToBorrowRequestAddress[user];
    }

    function getBorrowRequestDetails(address user) 
    external 
    view 
    returns (uint256 depositedAmount, uint256 collateral) 
{
    borrowRequest memory request = userToBorrowRequestDetails[user];
    return (request.depositedAmount, request.collateral);
}



    // Function to check the contract's balance
    function getBalance() public view returns (uint256) {
     
        return address(this).balance;
    }

    // Function to retrieve details of a specific multisig
    // function getBorrowRequest_Parameters(address borrowRequestAddress)
    //     external
    //     view
    //     returns (address memory)
    // {
    //     return arrayOfAllBorrowRequests[borrowRequestAddress];
    // }
     receive() external payable {
        // Ether is received and stored in the contract
    }
}
