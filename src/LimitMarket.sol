// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Imports
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CreateMultiSig} from "./CreateMultiSig.sol";

// Errors
error NoCollateralSent(uint256);
error TransferFailed(address borrowrequest, uint256 sentAmount);
error OnlyOwnerAllowed();
error InsufficientBalance(uint256 balance, uint256 collateral);
error inValidAmount(uint256 balance, uint256 amountsent);
error NoAmountSent(uint256 balance, uint256 amountsent);

// Type Declarations
struct MultiSigDetails {
    uint256 depositedAmount;
    uint256 collateral;
}

// Contract Definition
contract LimitMarket {
    using SafeERC20 for IERC20;


    // State Variables
    mapping(address => address[]) public userToMultiSigs; // Mapping for all multisigs created by users
    mapping(address => MultiSigDetails) public multiSigDetails; // Struct holding multisig details
    mapping(address => address[]) public borrowRequests; // Supports multiple multisig requests per contract


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
    constructor() {}

    // Function to create a multisig contract between this contract and the caller, and transfer Ether to the newly created multisig
    function createMultiSig(uint256 _collateral) external payable {
        // Check the amount to send is valid
        if (msg.value == 0) revert NoAmountSent(msg.sender.balance, msg.value);
        if (msg.value > msg.sender.balance) revert inValidAmount(msg.sender.balance, msg.value);
        if (_collateral <= 0) revert NoCollateralSent(msg.value);
        if (_collateral >= msg.sender.balance) revert InsufficientBalance(msg.sender.balance, _collateral);
         
         address[2] memory owners=[msg.sender,address(this)];
       
        CreateMultiSig multiSig = new CreateMultiSig(owners);

        // Store the deployed MultiSig contract address
        userToMultiSigs[msg.sender].push(address(multiSig));


        // Store the multisig details in the struct
        multiSigDetails[address(multiSig)] = MultiSigDetails({
            depositedAmount: msg.value,
            collateral: _collateral
        });

        // Store the borrow request for this multisig
        borrowRequests[address(this)].push(address(multiSig));

        // Transfer the Ether to the multisig contract
        (bool success, ) = payable(address(multiSig)).call{
            value: msg.value, gas: 2300
        }("");
        if (!success) revert TransferFailed(address(multiSig), msg.value);

        // Emit events
        emit MultiSigCreated(msg.sender, address(multiSig), msg.value);
        emit MultiSigDetailsUpdated(address(multiSig), msg.value, _collateral);
    }

    // Function to retrieve all multisig contracts for a user
    function getUserMultiSigs(address user)
        external
        view
        returns (address[] memory)
    {
        return userToMultiSigs[user];
    }
    // Function to check the contract's balance
    function getBalance() public view returns (uint256) {
     
        return address(this).balance;
    }

    // Function to retrieve details of a specific multisig
    function getMultiSigDetails(address multiSig)
        external
        view
        returns (MultiSigDetails memory)
    {
        return multiSigDetails[multiSig];
    }
     receive() external payable {
        // Ether is received and stored in the contract

    }
}
