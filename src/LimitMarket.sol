// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CreateMultiSig} from "./CreateMultiSig.sol";

contract LimitMarket {
    using SafeERC20 for IERC20;

    // State variables
    address[] public listOfmultiSigContracts;
    mapping(address => address) public userToMultiSig; // Mapping to store the deployed multisig contract address for each user

    // Events
    event MultiSigCreated(address indexed user, address indexed multiSigAddress);

    // Constructor
    constructor() {}

    // Function to create a multisig contract between this contract and the caller
    function createMultiSig() public {
        require(userToMultiSig[msg.sender] == address(0), "MultiSig already exists for this user");

        // Define the owners (msg.sender and the LimitMarket contract)
        address[2] memory owners = [msg.sender, address(this)];

        // Deploy the CreateMultiSig contract
        CreateMultiSig multiSig = new CreateMultiSig(owners, 1); // Assuming 2 confirmations are required

        // Store the deployed MultiSig contract address mapped to the user
        userToMultiSig[msg.sender] = address(multiSig);
          listOfmultiSigContracts.push(address(multiSig));

        // Emit an event for the new multisig creation
        emit MultiSigCreated(msg.sender, address(multiSig));
    }

     function getAllMultisigAddress() public view returns (address[] memory){
        return listOfmultiSigContracts;
    }

    // Function to transfer Ether to the user's multisig contract
    function transferToMultiSig() public payable {
        require(msg.value > 0, "No Ether sent");
        address multiSig = userToMultiSig[msg.sender];
        require(multiSig != address(0), "No MultiSig for this user");

        // Transfer the Ether to the user's multisig contract
        (bool success, ) = multiSig.call{value: msg.value}("");
        require(success, "Transfer failed");
    }

    // Optional: Function to get the deployed MultiSig contract for a user
    function getUserMultiSig(address user) public view returns (address) {
        return userToMultiSig[user];
    }
}
