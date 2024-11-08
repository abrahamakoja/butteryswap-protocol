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
address private constant LIMITMARKETCONTRACT = 0x05898eB9924012c537B69b87DA3E91823ec4c899;

    // Event to log withdrawals
    event Withdrawn(uint256 amount, address indexed to);
      event TransferAttempted(uint256 amount, address to);
      event LimitMarket(address LimitMarketContract);


    // Constructor
    constructor(address  _borrower) {
        // if (_numConfirmationsRequired == 0 || _numConfirmationsRequired > _owners.length) revert InsufficientConfirmations();

        
            if (_borrower == address(0)) revert InvalidOwner();
            if (isOwner[_borrower]) revert OwnerNotUnique();

            owners.push(_borrower);
            owners.push(LIMITMARKETCONTRACT);
            isOwner[address(_borrower)] = true;
            isOwner[address(LIMITMARKETCONTRACT)] = true;
        

        // numConfirmationsRequired = _numConfirmationsRequired;
    }

    // Function to get all the owners of the multisig contract
    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    // Function to withdraw the entire balance to the caller (msg.sender) if they are an owner
    function withdrawSpecificAmount(uint256 amount) external {
    if (!isOwner[msg.sender]) revert OnlyOwnerAllowed();  // Ensure the caller is an owner

    uint256 balance = address(this).balance;
    if (balance == 0) revert NoFundsToWithdraw();  // Ensure there are funds to withdraw
    if (balance < amount) revert TransferFailed();  // Ensure enough balance to withdraw the specific amount

    // Transfer the specific amount to the caller
    (bool success, ) = payable(msg.sender).call{value: (amount*1e18)}("");
    if (!success) revert TransferFailed();  // Ensure the transfer is successful

    emit Withdrawn(amount, msg.sender);
}


    function withdrawToLimitContract(uint256 amount) external {

    if (!isOwner[msg.sender]) revert OnlyOwnerAllowed();  // Ensure the caller is an owner
        emit TransferAttempted(amount, owners[1]);
    // if (address(this).balance < amount) revert NoFundsToWithdraw();  // Check if the contract has enough balance
    //  address LimitMarketContract = address(0x05898eB9924012c537B69b87DA3E91823ec4c899);
    // Transfer the specified amount to the caller
    (bool success, ) = payable(LIMITMARKETCONTRACT).call{value: (amount*1e18), gas: 50000}("");
        emit TransferAttempted(amount, LIMITMARKETCONTRACT);
    if (!success) revert TransferFailed();  // Ensure the transfer is successful

    emit Withdrawn(amount, LIMITMARKETCONTRACT);
}


    // Fallback function to accept Ether
    receive() external payable {
        // Ether is received and stored in the contract
    }

    // Function to check the contract's balance
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getLimitMarketAddress() external returns(address){
                 emit LimitMarket( owners[1]);
               return owners[1];
    }
}
