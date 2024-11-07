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
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Enforcer_v1
 * @author Akoja
 * @notice This contract handles the execution of loan requests.
 * it gets the arrays of both borrow and lend requests and processes them in batches of 10 request at a time.
 * the batch processing ensures loans are executed in chronological order based of their block.timestamp when created.
 * this contract also implements a "bribe" mechanism that allows users to skip the que and have their loans executed next by paying an extra fee.
 * this fee is shared amongst the protocol and the users the briber cuts in front of.
 * this feature is experimental and may or may not be removed.
 */

// debug
import {Script, console} from "forge-std/Script.sol";


////////////////
/// Imports ///
//////////////


import {ButteryRun_v1} from "./ButteryRun_v1.sol";
import {LoanRequest} from "./LoanRequest.sol";
import {activeLoan} from "./activeLoan.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

////////////////////
/// Interfaces ///
/////////////////

// LimitMarket contract interface
interface ILimitMarket_v1 {
     function getActiveLendRequestContractAddressViaIndex( uint256 index) external view returns (address);
      function getTotalActiveLendRequestContractCount() external view returns (uint256);
    function getActiveBorrowRequestContractAddressViaIndex(uint256 index) external view returns(address);
    function getTotalActiveBorrowRequestContractCount() external view returns(uint256);
    function getActiveBorrowRequestViaLimit(uint256 startIndex, uint256 endIndex) external view returns(address[] memory);
}

// Borrow request interface
interface IBorrowRequest_v1 {
    function Owners(uint256 index) external view returns (address);

    function acceptLoan(address) external;

    function getBorrowRequestDetails()
        external
        view
        returns (
            address memeCoin,
            uint256 collateral,
            address[3] memory owners,
            uint256 balanceMinusFee,
            uint256 feeEarned,
            LoanRequest.RequestState state
        );
}
     
// Lend request contract interface
interface ILendRequest_v1 {
    function i_lender() external view returns (address);

    function offerLoan(address) external;

    function getLendRequestDetails()
        external
        view
        returns (
            uint256 amountLended,
            address[3] memory owners,
            uint256 balanceMinusFee,
            uint256 feeEarned,
            LoanRequest.RequestState state
        );
}

// Enforcer_v1 Contract Definition
contract Enforcer_v1 is Script, ButteryRun_v1, ReentrancyGuard, Ownable  {

    ////////////////
    /// Errors ///
    //////////////    
    
    error notEnoughLiquidity(/*uint256 availableLiquidity*/);/// @dev add total available liquidity later

    //////////////////////////
    /// Type Declarations ///
    ////////////////////////

    using LoanRequest for LoanRequest.BorrowRequest;
    using LoanRequest for LoanRequest.LendRequest;

    /////////////////////////
    /// State variables ////
    ///////////////////////
    
    uint256 private s_startingBorrowRequestIndex;
    uint256 private s_startingLendRequestIndex;
    address private limitMarketAddress;
    ILimitMarket_v1 limitMarket;
    address public activeBorrowRequestAddress; //keep track of the latest borrow request being processed.
    address public activeLendRequestAddress; //keep track of the latest lend request being processed.
    mapping(address => address[]) private userToActiveLoanContract;
    uint256 private constant BATCH_LIMIT = 10;

    ///////////////
    /// Events ///
    /////////////
    event loanOfferExecuted(
        address[3] owners,
        uint256 collateral,
        address memeCoin,
        uint256 amountLended
    );
    event MultiSigCreated(address indexed multiSigAddress);

    ///////////////////
    /// Modifiers ////
    /////////////////

    //////////////////
    /// Functions ///
    ////////////////

    /// @dev contract constructor.
    constructor() Ownable(msg.sender) {
        s_startingBorrowRequestIndex = 0; // initialize s_startingBorrowRequestIndex as 0
        s_startingLendRequestIndex = 0; // initialize s_startingLendRequestIndex as 0
    }

    receive() external payable {}

    //////////////////////////
    ///External Functions ///
    ////////////////////////

    /// @notice this function updates the LimitMarket contract address
    /// @dev This function can only be called by an Admin, notUpdating modifier ensures the proper state flow/management when this function is called.
    /// @param _limitMarketAddress this hold the contract address value passed when calling the function
    function updateLimitMarketContract(
        address _limitMarketAddress
    ) external onlyOwner notUpdating {
        // add checks
        _setUpdating(UpdateState.UPDATING);
        limitMarketAddress = _limitMarketAddress;
        limitMarket = ILimitMarket_v1(_limitMarketAddress);
        _setUpdating(UpdateState.NOTUPDATING);
    }

    /**
     * @notice this function processess the loan requests and executes them in a chronological order.
     * it ensures loans are handled on a "first come first serve" basis.
     * @dev  it loop through each batch and call a transfer function on each contract
     * get the active index and creates a new multisig address between the borrower, the lender and the enforcer contract
     * transfer requested ETH from lend request to the borrower address
     * transfer meme coin to the newly created multi sig address
     */
    function executeLoanRequests() external nonReentrant onlyOwner {

        // implement CEI
        /// @todo add enum states

        /// *** checks *** ///

        /// @dev check if there are loan requests available, if loan requests are less than 1 on both sides (borrow/lend), revert with the error notEnoughLiquidity
        if (limitMarket.getTotalActiveBorrowRequestContractCount() < 1 && limitMarket.getTotalActiveLendRequestContractCount() < 1 ) {
            revert notEnoughLiquidity();
        }

        /// *** effects *** ///
        uint256 _startingBorrowRequestIndex = s_startingBorrowRequestIndex;
        uint256 _startingLendRequestIndex = s_startingLendRequestIndex;
        // uint256 activeborrowRequestsIndex; 
        // uint256 activeLendRequestsIndex; 
        uint256 totalBorrowRequests = limitMarket.getTotalActiveBorrowRequestContractCount();
        uint256 totalLendRequests = limitMarket.getTotalActiveLendRequestContractCount();
       
        uint256 endIndexBorrow = _startingBorrowRequestIndex + BATCH_LIMIT > totalBorrowRequests
            ? totalBorrowRequests
            : _startingBorrowRequestIndex + BATCH_LIMIT; //ensure the batch limit of 10 is not exceeded for the endIndexBorrow variable

        uint256 endIndexLend = _startingLendRequestIndex + BATCH_LIMIT > totalLendRequests
            ? totalLendRequests
            : _startingLendRequestIndex + BATCH_LIMIT; //ensure the batch limit of 10 is not exceeded for the endIndexLend variable

        // gets and store the borrow requsts in a fixed number less than or equal to the batch limit
        // address[] memory borrowRequests = new address[](
        //     endIndexBorrow - _startingBorrowRequestIndex
        // );     
        address[] memory borrowRequests = limitMarket.getActiveBorrowRequestViaLimit(_startingBorrowRequestIndex,3);

        // gets and store the lend requsts in a fixed number less than or equal to the batch limit
        address[] memory lendRequests = new address[](
            endIndexLend - _startingLendRequestIndex
        );
        
        // @notice this variable checks for the lowest value between the borrow and lend requests array then assigns the lowest value between both to itself.
        // uint256 lowestRequestsCount = limitMarket.getTotalActiveBorrowRequestContractCount() <  limitMarket.getTotalActiveLendRequestContractCount() ? limitMarket.getTotalActiveBorrowRequestContractCount(): limitMarket.getTotalActiveLendRequestContractCount();
        uint256 startIndex = _startingBorrowRequestIndex <  _startingLendRequestIndex ? _startingBorrowRequestIndex: _startingLendRequestIndex;
         
        console.log("_startingBorrowRequestIndex",_startingBorrowRequestIndex); 
        console.log("borrowRequests",borrowRequests.length); 
        console.log("endIndexBorrow",endIndexBorrow); 
        console.log("lendRequests",lendRequests.length);
        console.log("startIndex",startIndex);
       
        // for (uint256 i = startIndex; i < BATCH_LIMIT; i++) {

        // // Loops through the loan requests and execute the offerLoan & acceptLoan functions, this would be done in batches of 10 at a time.
        // // starts from 0 and increments to 10

        //     /// *** borrow request effects *** ///
        //     activeborrowRequestsIndex = i - _startingBorrowRequestIndex;
        //     borrowRequests[activeborrowRequestsIndex] = limitMarket.getActiveBorrowRequestContractAddressViaIndex(i);//gets borrow request at index i
        //     address _activeBorrowRequestAddress = borrowRequests[activeborrowRequestsIndex];
        //     IBorrowRequest_v1 BorrowRequest = IBorrowRequest_v1(_activeBorrowRequestAddress);
        //     address activeBorrower = BorrowRequest.Owners(0);//change this
        //     // get borrow request details
        //     (address memeCoin, uint256 collateral, , , , ) = BorrowRequest.getBorrowRequestDetails();

        //     /// *** lend request effects *** ///
        //     activeLendRequestsIndex = i - _startingLendRequestIndex;
        //     lendRequests[activeLendRequestsIndex] = limitMarket.getActiveLendRequestContractAddressViaIndex(i);//compile error here
        //     address _activeLendRequestAddress =  lendRequests[activeLendRequestsIndex];
        //     ILendRequest_v1 LendRequest = ILendRequest_v1(_activeLendRequestAddress);
        //     address activeLender = LendRequest.i_lender();
        //     (uint256 amountLended, , , , ) = LendRequest.getLendRequestDetails();

        //     // create active loan vault owners address array
        //     address[3] memory owners = [
        //         activeBorrower,
        //         activeLender,
        //         address(this)//change this later
        //     ];

        //     // deploys new active loan vault
        //     activeLoan _activeLoan = new activeLoan(
        //         owners,
        //         collateral,
        //         memeCoin,
        //         amountLended
        //     );
            
        //     // update mapping of borrower address to active active loan
        //     userToActiveLoanContract[address(activeBorrower)].push( address(_activeLoan));
        //     // update mapping of lender address to active active loan
        //     userToActiveLoanContract[address(activeLender)].push(address(_activeLoan));
        //     // update activeBorrowRequestAddress
        //     activeBorrowRequestAddress = _activeBorrowRequestAddress;
        //     // s_startingBorrowRequestIndex = last executed borrow index
        //     emit loanOfferExecuted(owners, collateral, memeCoin, amountLended);
        //     emit MultiSigCreated(address(_activeLoan));
              
        //      /// *** interactions *** ///  
        //     BorrowRequest.acceptLoan(address(_activeLoan)); //transfers collateral from borrow request to active loan vault address.
        //     LendRequest.offerLoan(address(activeBorrower)); //transfers requested native token amount to borrowers address.
        //     // collect fee
        // }
    }
    

    /////////////////////////////////////////////////
    ///  internal & private view & pure functions ///
    ////////////////////////////////////////////////

    

    ////////////////////////////////////////////////
    /// External & Public View & Pure Functions ///
    //////////////////////////////////////////////

 /// @notice This function returns the array of active Loans attached to a specific user.
 /// @param user: address of the user. 
 /// @return adress[]: array of active loan addresses,
    function getUserActiveLoanContracts(
        address user
    ) external view returns (address[] memory) {
        return userToActiveLoanContract[user]; // Retrieve active borrow contracts for the specified user
    }


    /// @dev this function returns the address of the current limitMarket contract
    /// @return limitMarketContract the return variables of a contract’s function state variable
    function getLimitMarketContractAddress()
        public
        view onlyOwner
        returns (address limitMarketContract)
    {
        return limitMarketAddress;
    }
}
