// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CreateMultiSig} from "./CreateMultiSig.sol";

contract LimitMarket {
    using SafeERC20 for IERC20;

    // State variables
    mapping(address => address) public userToMultiSig; // Mapping to store the deployed multisig contract address for each user

    // Events
    event MultiSigCreated(address indexed user, address indexed multiSigAddress, uint256 amountTransferred);

    // Constructor
    constructor() {}

    // Function to create a multisig contract between this contract and the caller, and transfer Ether to the newly created multisig
    function createMultiSig() public payable {
        require(userToMultiSig[msg.sender] == address(0), "MultiSig already exists for this user");
        require(msg.value > 0, "No Ether sent");  // Ensures Ether is sent with the function call

        // Define the owners (msg.sender and the LimitMarket contract)
        address[2] memory owners = [msg.sender, address(this)];

        // Deploy the CreateMultiSig contract
        CreateMultiSig multiSig = new CreateMultiSig(owners, 2); // Assuming 2 confirmations are required

        // Store the deployed MultiSig contract address mapped to the user
        userToMultiSig[msg.sender] = address(multiSig);

        // Transfer the Ether to the multisig contract
        (bool success, ) = payable(address(multiSig)).call{value: msg.value}(""); // Ether is sent to multisig
        require(success, "Transfer failed");

        // Emit an event for the new multisig creation with the amount of Ether transferred
        emit MultiSigCreated(msg.sender, address(multiSig), msg.value);
    }

    // Optional: Function to get the deployed MultiSig contract for a user
    function getUserMultiSig(address user) public view returns (address) {
        return userToMultiSig[user];
    }
}
