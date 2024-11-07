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

/** imports*/

// SPDX-License-Identifier: MIT

/**
 * @title Multi-sig initializer contract
 * @author Butteryswap
 * @notice This contract creates multisig wallet between protocol users and the loan execution contract.
 * @dev This implements multi-sig initialization process before each loan contract is executed.
 */
pragma solidity ^0.8.20;

/** imports*/
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CreateMultiSig {

    // using SafeERC20 for IERC20;

    /** errors*/
    error CreateMultisig_NotOwner();
    // error CreateMultisig_InvalidNoOfSigners();
    // error CreateMultisig_InvalidNoOfConfirmations();
    // error CreateMultisig_InvalidOwner();
    // error CreateMultisig_OwnerNotUnique();
    error TxNotExist();
    error NotEnoughBalance();
    error TxNotAlreadyExecuted();
    error TxNotAlreadyConfirmed();
    error MemeCoinNotSupported();
    error CreateMultisig_ContractIsOwner();
    error ContractClosed();

    /** Type declarations */
    // enums ,structs, special types
    // struct User {
    //     // later make this sruct work from the executor contract
    //     address borrower;
    //     address memeCoinAddress;
    //     uint256 memeCoinAmount;
    //     uint256 nativeTokenAmount;
    // }

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
    }

    /**  State variables */
    // external contract variable

    /*local variables*/
    // address private s_borrower;
    // address private s_memeCoin;
    // address private s_nativeToken; //native token of contract blockchain
    // address private s_multisigAddress;
    // uint256 private immutable i_memeCoinAmount;
    // uint256 private immutable i_nativeTokenAmount;
    uint256 private constant ESTIMATED_FEE = 8e9;
    uint256 private constant NUM_OF_CONFIRMATIONS = 1;
    uint256 public numConfirmationsRequired;
    bool public contractIsOwner;
    uint256 linkBalance;
    address public multiSigAddress;
    address public constant LINK_ADDRESS =
        0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address[] public owners;
    address[] public supportedMemeCoins;
    // IERC20 public linkToken;
    // User[] public u_borrower;
    Transaction[] public transactions;
    mapping(address => bool) public supportedMemeCoinsList;
    // mapping(address => User) public pendingBorrowContract;
    mapping(address => bool) public isOwner;
    // mapping from tx index => owner => bool
    mapping(uint256 => mapping(address => bool)) public isConfirmed;
    //

    /** Events */
    // event LoanRequested(address indexed borrower);
    // event LoanDetailsRecorded();
    // event MemeCoinAmountTransffered(uint256 indexed memeCoinAmount);
    // event MultiiSgCreated(address indexed multiSigAddress);
    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event SubmitTransaction(
        address indexed owner,
        uint256 indexed txIndex,
        address indexed to,
        uint256 value,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);

    /** modifiers */
    // checks and ensure meme coin is supported by butteryswap protocol
    // modifier memeCoinSupported() {
    //     if (s_memeCoin === address(0)) {
    //         emit LoanDetailsRecorded();
    //     }
    //     _;
    // }

    modifier onlyOwner() {
        if (isOwner[msg.sender]) {
            revert CreateMultisig_NotOwner();
        }
        _;
    }

    modifier txExists(uint256 _txIndex) {
        if (_txIndex < transactions.length) {
            revert TxNotExist();
        }
        _;
    }

    modifier notExecuted(uint256 _txIndex) {
        if (!transactions[_txIndex].executed) {
            revert TxNotAlreadyExecuted();
        }

        _;
    }

    modifier notConfirmed(uint256 _txIndex) {
        if (!isConfirmed[_txIndex][msg.sender]) {
            revert TxNotAlreadyConfirmed();
        }
        _;
    }

    /**  checks if user wallet has sufficient balance of selected memecoin
     * @notice formulae for this version is as below;
     *    amount>= available balance of memecoin + total fees
     */
    modifier memeCoinIsSupported(uint256 _txIndex, address _memeCoin) {
        if (!supportedMemeCoinsList[_memeCoin]) {
            revert MemeCoinNotSupported();
        }
        _;
    }

    /** functions */

    /** construstor */
    constructor() {
        // check if multisig already has owners and if owned already by user
        if ((owners.length > 0) && (!isOwner[msg.sender])) {
            revert ContractClosed();
        } else {
            owners.push(msg.sender);
            isOwner[address(msg.sender)] = true;
            isConfirmed[0][msg.sender] = true;
            // linkToken = IERC20(LINK_ADDRESS);
            // u_borrower.borrower = msg.sender;

            // u_borrower.push(
            //     User({
            //         borrower: msg.sender,
            //         memeCoinAddress:address(0),
            //         memeCoinAmount: 3,
            //         nativeTokenAmount: 1
            //     })
            // );

            // linkBalance = linkToken.balanceOf(msg.sender);
            //    transferTokens(linkToken,address(this),0);
            // pendingBorrowContract[address(this)] = u_borrower[0];
            // linkToken.allowance(msg.sender, address(this));
            // linkToken.approve( address(this),1);
            // linkToken.transferFrom(msg.sender, address(this), 1);
            // linkToken.allowance(msg.sender,address(this));

            // transferMemeCoin();
        }

        // if ( IERC20(0x779877A7B0D9E8603169DdbD7836e478b4624789).balanceOf(msg.sender) <= 10) {
        //     revert NotEnoughBalance();
        // }

        if (contractIsOwner) {
            revert CreateMultisig_ContractIsOwner();
        } else {
            owners.push(address(this));
            multiSigAddress = address(this);
            isOwner[address(this)] = true;
            isConfirmed[1][address(this)] = true;
            contractIsOwner = true;
         
            // linkToken.transfer(address(this), 2);
        }

        numConfirmationsRequired = NUM_OF_CONFIRMATIONS;
        //  linkToken.approve(multiSigAddress, 1);

        // assignContractAsOwner();
    }

    // Receive function to deposit Ether into the Multisig wallet
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    // defaults to main function
    // fallback() external payable {}

    // function transferMemeCoin() public payable onlyOwner {
    //     // if (linkToken.balanceOf(msg.sender) < 1) {
    //         linkToken.transfer(multiSigAddress, 20);
    //     // }
    // }

//  function transferTokens(IERC20 token, address to, uint256 amount) public onlyOwner {
//         // Using SafeERC20's safeTransfer function which checks the return value
//         token.safeTransfer(to, amount);
//     }
    /**
     * @dev This function creates a
     * calls to send the money to the random winner.
     */
    // assign contract as owner after user has deployed
    function assignContractAsOwner() internal onlyOwner {
        if (contractIsOwner) {
            revert CreateMultisig_ContractIsOwner();
        } else {
            owners.push(address(this));
            isOwner[address(this)] = true;

            contractIsOwner = true;
        }
    }

    function submitTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    ) public onlyOwner {
        uint256 txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0
            })
        );
        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    function confirmTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "cannot execute tx"
        );

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    function getlinkBalance() public view returns (uint256) {
        return linkBalance;
    }

    function getTransaction(uint256 _txIndex)
        public
        view
        returns (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 numConfirmations
        )
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }
}
