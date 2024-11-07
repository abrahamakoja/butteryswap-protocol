// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Errors
error InvalidOwner();
error OwnerNotUnique();
error InsufficientConfirmations();
error OnlyOwnerAllowed();
error NoFundsToWithdraw();
error TransferFailed();

// Type Declarations
struct MultiSigDetails {
    uint256 balance;
    uint256 amountToReceive;
}

// Contract Definition
contract CreateMultiSig {
    // State Variables
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public numConfirmationsRequired;

    // Event to log withdrawals
    event Withdrawn(uint256 amount, address indexed to);

    // Constructor
    constructor(address[2] memory _owners, uint256 _numConfirmationsRequired) {
        if (_numConfirmationsRequired == 0 || _numConfirmationsRequired > _owners.length) revert InsufficientConfirmations();

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            if (owner == address(0)) revert InvalidOwner();
            if (isOwner[owner]) revert OwnerNotUnique();

            owners.push(owner);
            isOwner[owner] = true;
        }

        numConfirmationsRequired = _numConfirmationsRequired;
    }

    // Function to get all the owners of the multisig contract
    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    // Function to withdraw the entire balance to the caller (msg.sender) if they are an owner
    function withdrawAll() external {
        if (!isOwner[msg.sender]) revert OnlyOwnerAllowed();  // Ensure the caller is an owner

        uint256 balance = address(this).balance;
        if (balance == 0) revert NoFundsToWithdraw();  // Ensure there are funds to withdraw

        // Transfer the balance to the caller
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        if (!success) revert TransferFailed();  // Ensure the transfer is successful

        // Emit event (optional)
        emit Withdrawn(balance, msg.sender);
    }

    // Fallback function to accept Ether
    receive() external payable {
        // Ether is received and stored in the contract
    }

    // Function to check the contract's balance
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
