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
    uint256 public balanceMinusFee;
    address private LIMITMARKETCONTRACT;

    // Event to log withdrawals
    event Withdrawn(uint256 amount, address indexed to);
    event TransferAttempted(uint256 amount, address to);
    event LimitMarket(address LimitMarketContract);
    event OwnersAdded(address LimitMarketContract, address borrower);
 

    // Constructor
    constructor(address[2] memory _owners) {
        // if (_numConfirmationsRequired == 0 || _numConfirmationsRequired > _owners.length) revert InsufficientConfirmations();

for (uint256 i; _owners.length >i; i++) 
{
    if (_owners[0] == address(0)) revert InvalidOwner();
        if (isOwner[_owners[i]]) revert OwnerNotUnique();
    
        owners.push(_owners[i]);
        isOwner[address(_owners[i])] = true;
        // owners.push(LIMITMARKETCONTRACT);
        // isOwner[address(LIMITMARKETCONTRACT)] = true;
}
       

        emit OwnersAdded(_owners[0], _owners[1]);
        // numConfirmationsRequired = _numConfirmationsRequired;
    }

    // Function to get all the owners of the multisig contract
    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    // Function to withdraw the entire balance to the caller (msg.sender) if they are an owner
    function withdrawSpecificAmount(uint256 amount) external {
        if (!isOwner[msg.sender]) revert OnlyOwnerAllowed(); // Ensure the caller is an owner

        uint256 balance = address(this).balance;
        if (balance == 0) revert NoFundsToWithdraw(); // Ensure there are funds to withdraw
        if (balance < amount) revert TransferFailed(); // Ensure enough balance to withdraw the specific amount

        // Transfer the specific amount to the caller
        (bool success, ) = payable(msg.sender).call{value: (amount * 1e18)}("");
        if (!success) revert TransferFailed(); // Ensure the transfer is successful

        emit Withdrawn(amount, msg.sender);
    }

    function withdrawToLimitContract(uint256 amount) external {
        if (!isOwner[msg.sender]) revert OnlyOwnerAllowed(); // Ensure the caller is an owner

        (bool success, ) = payable(owners[1]).call{
            value: (amount * 1e18),
            gas: 50000
        }("");
        emit TransferAttempted(amount, owners[1]);
        if (!success) revert TransferFailed(); // Ensure the transfer is successful

        emit Withdrawn(amount, owners[1]);
    }

    // Fallback function to accept Ether
    receive() external payable {
        // Ether is received and stored in the contract
    }

    // Function to check the contract's balance
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getLimitMarketAddress() external view returns (address) {
        //  emit LimitMarket(LIMITMARKETCONTRACT);
        return owners[1];
    }
}
