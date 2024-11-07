// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Imports
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CreateMultiSig} from "./CreateMultiSig.sol";

// Errors
error NoEtherSent();
error TransferFailed();
error OnlyOwnerAllowed();
error InsufficientBalance();

// Type Declarations
struct MultiSigDetails {
    uint256 depositedAmount;
    uint256 amountToReceive;
}

// Contract Definition
contract LimitMarket {
    using SafeERC20 for IERC20;

    // State Variables
    mapping(address => address[]) public userToMultiSigs;  // Mapping for all multisigs created by users
    mapping(address => MultiSigDetails) public multiSigDetails;  // Struct holding multisig details
    mapping(address => address[]) public borrowRequests;  // Now supports multiple multisig requests per contract

    // Events
    event MultiSigCreated(address indexed user, address indexed multiSigAddress, uint256 amountTransferred);
    event MultiSigDetailsUpdated(address indexed multiSigAddress, uint256 depositedAmount, uint256 amountToReceive);

    // Constructor
    constructor() {}

    // Function to create a multisig contract between this contract and the caller, and transfer Ether to the newly created multisig
    function createMultiSig(uint256 _amountToReceive) external payable {
        if (msg.value == 0) revert NoEtherSent();

        // Define the owners (msg.sender and the LimitMarket contract)
        address[2] memory owners = [msg.sender, address(this)];

        // Deploy the CreateMultiSig contract
        CreateMultiSig multiSig = new CreateMultiSig(owners, 2);  // 2 confirmations required

        // Store the deployed MultiSig contract address
        userToMultiSigs[msg.sender].push(address(multiSig));

        // Store the multisig details in the struct
        multiSigDetails[address(multiSig)] = MultiSigDetails({
            depositedAmount: msg.value,
            amountToReceive: _amountToReceive
        });

        // Store the borrow request for this multisig
        borrowRequests[address(this)].push(address(multiSig));

        // Transfer the Ether to the multisig contract
        (bool success, ) = payable(address(multiSig)).call{value: msg.value}("");
        if (!success) revert TransferFailed();

        // Emit events
        emit MultiSigCreated(msg.sender, address(multiSig), msg.value);
        emit MultiSigDetailsUpdated(address(multiSig), msg.value, _amountToReceive);
    }

    // Function to retrieve all multisig contracts for a user
    function getUserMultiSigs(address user) external view returns (address[] memory) {
        return userToMultiSigs[user];
    }

    // Function to retrieve details of a specific multisig
    function getMultiSigDetails(address multiSig) external view returns (MultiSigDetails memory) {
        return multiSigDetails[multiSig];
    }
}
