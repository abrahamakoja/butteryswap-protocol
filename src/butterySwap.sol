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
// view & pure functions

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;


import {CreateMultisig} from "./CreateMultisig.sol";

contract ButterySwap is CreateMultisig {
    constructor(address[] memory initialOwners, uint256 requiredConfirmations) 
        CreateMultisig(initialOwners, requiredConfirmations) {
    }
    // State variables
    mapping(address => address[]) public deployerToContracts;
    
    // Events
    event MultisigDeployed(address indexed deployer, address indexed contractAddress);
    
    // Track new multisig contract deployments
    function trackMultisigDeployment(address _contractAddress) public {
        deployerToContracts[msg.sender].push(_contractAddress);
        emit MultisigDeployed(msg.sender, _contractAddress);
    }

    // View function to get all contracts deployed by an address
    function getDeployedContracts(address _deployer) public view returns (address[] memory) {
        return deployerToContracts[_deployer];
    }


}
