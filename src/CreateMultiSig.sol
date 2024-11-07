// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CreateMultiSig {
    // State variables
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public numConfirmationsRequired;
    // mapping(uint256 => mapping(address => bool)) public isConfirmed;

    // Constructor: Initializes the contract with the owners and required confirmations
    constructor(address[2] memory _owners, uint256 _numConfirmationsRequired) {
        require(_numConfirmationsRequired > 0 && _numConfirmationsRequired <= _owners.length, "Invalid number of confirmations");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");

            owners.push(owner);
            isOwner[owner] = true;
        }

        numConfirmationsRequired = _numConfirmationsRequired;
    }

    // Function to get all the owners of the multisig contract
    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    // Fallback function to accept Ether
    receive() external payable {
        // Ether is received and stored in the contract
    }

    // Function to check contract's balance (optional)
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
