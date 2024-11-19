// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Contract Definition
contract CreateBorrowRequest_v1 {

    // Errors
    error InvalidOwner();        
    error OwnerNotUnique();
    error InsufficientConfirmations();
    error OnlyOwnerAllowed();
    error NoFundsToWithdraw(uint256 s_BALANCE, uint256 contracAddress);
    error StillOpen();
    error TransferFailed(uint256 balanceMinusFee, uint256 contractBalance);
    error finalTransferFailed(address contractAddress, uint256 contractBalance);

    // Type declarations
    enum ContractState {
        OPEN, CANCELLING, CLOSED
    }

    // State Variables
    uint256 public memeCoinAmountSent;
    uint256 private constant CANCELFEE = 5;
    uint256 public numConfirmationsRequired;
    uint256 public balanceMinusFee;
    address private LIMITMARKETCONTRACT;
    address[] public owners;
    mapping(address => bool) public isOwner;
    ContractState private s_contractState;

    // Events
    event contractCancelled(address[] owners, uint256 final_balance);
    event finalBalanceWithdrawn(uint256 contractBalance, address contractAddress);
    event TransferAttempted(uint256 amount, address to);
    event LimitMarket(address LimitMarketContract);
    event OwnersAdded(address LimitMarketContract, address borrower);
    event userWithdrawnCollateral(uint256 amountWithDrawn, uint256 amountSentToContract);

     // Modifier to restrict function calls to owners only
    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert OnlyOwnerAllowed(); // Reverts if the caller is not an owner
        _;
    }


    // Constructor
    constructor(address[2] memory _owners, uint256 _memeCoinAmountSent) {
        s_contractState = ContractState.OPEN;
        for (uint256 i; _owners.length > i; i++) {
            if (_owners[0] == address(0)) revert InvalidOwner();
            if (isOwner[_owners[i]]) revert OwnerNotUnique();
            
            owners.push(_owners[i]);
            isOwner[address(_owners[i])] = true;
            memeCoinAmountSent = _memeCoinAmountSent;
        }
        emit OwnersAdded(_owners[0], _owners[1]);
    }

    // Fallback function to accept Ether
    receive() external payable {}

   
    // Function to get all the owners of the multisig contract
    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    // Function to cancel borrow request (restricted to owners)
    function cancelBorrowRequest() external onlyOwner {
        // checks
        if (address(this).balance == 0) revert NoFundsToWithdraw(address(this).balance, address(this).balance);
        if (address(this).balance < balanceMinusFee) revert TransferFailed(balanceMinusFee, address(this).balance);

        // effects
        s_contractState = ContractState.CANCELLING;
        balanceMinusFee = address(this).balance ;
      

        // interactions
        (bool success, ) = payable(msg.sender).call{value: balanceMinusFee - ((address(this).balance * 5) / 1000)}("");
        if (!success) revert TransferFailed(balanceMinusFee, address(this).balance);
        if(success) emit userWithdrawnCollateral( balanceMinusFee - ((address(this).balance * 5) / 1000), ((address(this).balance * 5) / 1000));
        s_contractState = ContractState.CLOSED;
        if (s_contractState == ContractState.CLOSED) {
            withdrawBalanceToLimitMarketContract();
        }
    }

    function withdrawBalanceToLimitMarketContract() internal onlyOwner {
        if (!(s_contractState == ContractState.CLOSED)) revert StillOpen();

        (bool success, ) = payable(owners[1]).call{
            value: address(this).balance,
            gas: 50000
        }("");

        if (!success) revert finalTransferFailed(owners[1], address(this).balance);
        emit finalBalanceWithdrawn(address(this).balance, owners[1]);

        delete owners;
        emit contractCancelled(owners, address(this).balance);
    }

    // Function to check the contract's balance
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getCalculation()external view returns(uint256){
         return (address(this).balance * 5) / 1000;

    }

    // // Function to check the amount of memeCoin sent
    // function getAmountSent() external view returns (uint256) {
    //     return memeCoinAmountSent;
    // }

    // // Function to get the LimitMarket address
    // function getLimitMarketAddress() external view returns (address) {
    //     return owners[1];
    // }

    // // Function to get this contract's address
    // function getThisContractAddress() external view returns (address) {
    //     return address(this);
    // }
}
