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
 * this contract also implements a "priorioty boost" mechanism that allows users to skip the que and have their loans executed next by paying an extra fee.
 * this fee is shared amongst the protocol and the users within the loan requests that eventually seeds the priority loan.
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
    function getPrioritizedBorrowRequestAddress() external view returns(address loanRequest);
     function getPrioritizedLendRequestAddress() external view returns(address loanRequest);
      function getTotalActiveLendRequestContractCount() external view returns (uint256);
    function getTotalActiveBorrowRequestContractCount() external view returns(uint256);
    function getActiveBorrowRequestViaLimit(uint256 startIndex, uint256 endIndex) external view returns(address[] memory);
    function getActiveLendRequestViaLimit(uint256 startIndex, uint256 requestedNumber) external view returns(address[] memory);
   
    
}

// Borrow request interface
interface IBorrowRequest_v1 {
    function i_borrower() external view returns (address);
    function Owners(uint256 index) external view returns (address);
    
    function acceptLoan(address) external;

    function getBorrowRequestDetails()
        external
        view
        returns (
            address memeCoin,
            uint256 collateral,
            address[2] memory owners,
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
            address[2] memory owners,
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
    
    error Enforcer_v1_insufficientLiquidity(/*uint256 availableLiquidity*/);/// @dev add total available liquidity later
  error Enforcer_v1_loanProcessingInProgress();
     

    //////////////////////////
    /// Type Declarations ///
    ////////////////////////

    ///////////////
    /**  Enums **/
    /////////////

    /// @notice used in tracking state of the executeLoanRequests() function, when active state is set to PROCESSING and IDLE when it is not being called.
    enum executionState{
        PROCESSING,
        IDLE
    }

    /////////////////////////
    /// State variables ////
    ///////////////////////
    IBorrowRequest_v1 BorrowRequest ;
    ILendRequest_v1 LendRequest ;
    executionState private currentLoanState;
    uint256 private s_startingBorrowRequestIndex;
    uint256 private s_startingLendRequestIndex;
    address private s_limitMarketAddress;
    ILimitMarket_v1 limitMarket;
    /// @dev keeps count on the number of times a batch was processed by the executeLoanRequests() function.
    uint256 private s_batchCount;
    uint256 private s_priorityCount;
    address private s_activeBorrowRequestAddress; //keep track of the latest borrow request being processed.
    address private s_activeLendRequestAddress; //keep track of the latest lend request being processed.
    mapping(address => address[]) private userToActiveLoanContract;
    mapping(address borrowRequest => uint256 index) private s_settledBorrowRequest; // 
    mapping(address borrowRequest => uint256 index) private s_settledLendRequest; // 
    uint256 private constant BATCH_LIMIT = 10;


    ///////////////
    /// Events ///
    /////////////

    event loanOfferExecuted(address indexed activeLoan);

    ///////////////////
    /// Modifiers ////
    /////////////////

    modifier onlyWhenIdle{
       if (currentLoanState == executionState.PROCESSING) revert Enforcer_v1_loanProcessingInProgress();
        _;
    }

    //////////////////
    /// Functions ///
    ////////////////

    /// @dev contract constructor.
    constructor() Ownable(msg.sender) {
        s_startingBorrowRequestIndex = 0; // initialize s_startingBorrowRequestIndex as 0
        s_startingLendRequestIndex = 0; // initialize s_startingLendRequestIndex as 0
        s_batchCount = 0; // initialize batch count to 0
        currentLoanState = executionState.IDLE;
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
        if (_limitMarketAddress == address(0)) {
            revert();
        }
        _setUpdating(UpdateState.UPDATING);
        s_limitMarketAddress = _limitMarketAddress;
        limitMarket = ILimitMarket_v1(s_limitMarketAddress);
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
    function executeLoanRequests() external nonReentrant onlyOwner onlyWhenIdle {
          _executionState(executionState.PROCESSING);
        /// *** checks *** ///
        
        /// @dev check if liquidity is sufficient to settle loans, if loan requests are less than 1 on either sides ie;(borrow/lend), revert with the error Enforcer_v1_insufficientLiquidity
        if (limitMarket.getTotalActiveBorrowRequestContractCount() < 1 || limitMarket.getTotalActiveLendRequestContractCount() < 1 ) {
            revert Enforcer_v1_insufficientLiquidity();
        }

        /// *** effects *** ///

        uint256 totalBorrowRequests = limitMarket.getTotalActiveBorrowRequestContractCount();
        uint256 totalLendRequests = limitMarket.getTotalActiveLendRequestContractCount();

        // priority
        address prioritizedBorrowRequest = limitMarket.getPrioritizedBorrowRequestAddress();
        address prioritizedLendRequest = limitMarket.getPrioritizedLendRequestAddress();

        address[] memory borrowRequests = limitMarket.getActiveBorrowRequestViaLimit(s_startingBorrowRequestIndex,totalBorrowRequests);
        /// @dev gets and store the lend requests in a fixed number less than or equal to the batch limit
         address[] memory lendRequests = limitMarket.getActiveLendRequestViaLimit(s_startingLendRequestIndex,totalLendRequests);
        
        /// @notice this variable checks for the lowest value between the borrow and lend requests array then assigns the lowest value between both to itself.
        uint256 lowestRequestsCount = limitMarket.getTotalActiveBorrowRequestContractCount() <  limitMarket.getTotalActiveLendRequestContractCount() ? limitMarket.getTotalActiveBorrowRequestContractCount(): limitMarket.getTotalActiveLendRequestContractCount();
        uint256 batchLimit = lowestRequestsCount < BATCH_LIMIT ? lowestRequestsCount : BATCH_LIMIT ; //ensure the batch limit of 10 is not exceeded for the endIndexLend variable
       
   console.log("totalBorrowRequests ",borrowRequests.length);
   console.log("totalLendRequests ",totalLendRequests);
    
    // console.log("before startIndex",startIndex);
     console.log("******************before********************");

        for (uint256 i = 0; i < batchLimit; i++) {
            /// @dev this Loops through the loan requests and execute the offerLoan & acceptLoan functions, this would be done in batches of 10 at a time.
              console.log("**************start loop**********");
            address _activeBorrowRequestAddress =  borrowRequests[i];
            address _activeLendRequestAddress = lendRequests[i];
           
            _processLoan(_activeBorrowRequestAddress,_activeLendRequestAddress,i);
            console.log("**************end loop**********");
        }
            console.log("*************************************************");
            // console.log("after totalBorrowRequests ",borrowRequests.length);
            // console.log("after totalLendRequests ",totalLendRequests);
            console.log("after last settled borrow index",s_settledBorrowRequest[address(s_activeBorrowRequestAddress)]);
            console.log("last borrow",s_activeBorrowRequestAddress); 
            console.log("last lend",s_activeLendRequestAddress);
           
        
        // handle priority loans  
       _prioritizeBorrowLoan( prioritizedBorrowRequest,  lendRequests);
       _prioritizeLendLoan(prioritizedLendRequest,borrowRequests);

            console.log("*****************concluded************************");
            // console.log("last totalBorrowRequests ",borrowRequests.length);
            // console.log("last totalLendRequests ",totalLendRequests);
            console.log("after priority settled index",s_settledBorrowRequest[address(s_activeBorrowRequestAddress)]);
            console.log("last priority borrow",s_activeBorrowRequestAddress); 
            console.log("last priority lend",s_activeLendRequestAddress);

              s_batchCount++;
                 console.log("called function ",s_batchCount,"times");
                 console.log("called  priority",s_priorityCount,"times");
              _executionState(executionState.IDLE);
    }
    

    /////////////////////////////////////////////////
    ///  internal & private view & pure functions ///
    ////////////////////////////////////////////////


/// @dev This function allows users to pay a priority fee that allows their loan to be processed quicker,
/// it works by injecting the prioritized loan address right after a concluded batch is processed,
/// fee is in protocol token $BUTTER, and all collected fee is distributed to every user on the next batch after the prioritized loan is settled.
/// if available, a maximum of 2 prioritized loans would be processes after a batch, one for each different loan types.
/// this will ensure processing priority loans doesn't creates a bottle neck for other batches to go through.
    function _prioritizeBorrowLoan(address _prioritizedBorrowRequest, address[] memory lendRequests) internal {
       // handle priority for borrow request loans
        if (_prioritizedBorrowRequest != address(0) && lendRequests.length != 0) {  
            console.log("**************inside borrow priority**********");
            console.log(" prioritizedBorrowRequest",_prioritizedBorrowRequest);

            uint256 lastLendRequestProcessed = s_settledLendRequest[address(s_activeLendRequestAddress)];
            uint256 targetRequestIndex = lastLendRequestProcessed + 1;
            address _activeBorrowRequestAddress = address(_prioritizedBorrowRequest);
            address _activeLendRequestAddress = lendRequests[targetRequestIndex];

             _processLoan(_activeBorrowRequestAddress,_activeLendRequestAddress,targetRequestIndex);
             s_priorityCount++;

            console.log("target index nextBorrowRequest",targetRequestIndex);
            console.log("target address _activeBorrowRequestAddress",_activeBorrowRequestAddress);
            console.log("target address _activeLendRequestAddress",_activeLendRequestAddress);
            console.log("priority handled",_activeBorrowRequestAddress);
            console.log("**************end borrow priority**********");
        }
    }
    function _prioritizeLendLoan(address _prioritizedLendRequest, address[] memory borrowRequests) internal {
            if (_prioritizedLendRequest != address(0) &&  limitMarket.getTotalActiveBorrowRequestContractCount() != 0) {
            if ( limitMarket.getTotalActiveBorrowRequestContractCount() == 0) {
                return;//extra check cus i am paranoid
            } else {
                
            
            console.log("**************inside lend priority**********");
            console.log(" prioritizedLendRequest",_prioritizedLendRequest);
            uint256 lastBorrowRequestProcessed = s_settledBorrowRequest[address(s_activeBorrowRequestAddress)];
           
            uint256 targetRequestIndex = lastBorrowRequestProcessed + 1;
            address _activeLendRequestAddress = address(_prioritizedLendRequest);
        
             address _activeBorrowRequestAddress = borrowRequests[targetRequestIndex];

             _processLoan(_activeBorrowRequestAddress,_activeLendRequestAddress,targetRequestIndex);
             s_priorityCount++;

            console.log("target index nextBorrowRequest",targetRequestIndex);
            console.log("target address _activeBorrowRequestAddress",_activeBorrowRequestAddress);
            console.log("target address _activeLendRequestAddress",_activeLendRequestAddress);
            console.log("priority handled",_activeLendRequestAddress);
            console.log("**************end lend priority**********");
            }
        }
    }
    function _processLoan(address _activeBorrowRequestAddress, address _activeLendRequestAddress, uint256 index) internal {

               /// *** borrow request effects *** ///
             BorrowRequest = IBorrowRequest_v1(_activeBorrowRequestAddress);
              address activeBorrower = BorrowRequest.i_borrower();
            (address memeCoin, uint256 collateral, , , ,) = BorrowRequest.getBorrowRequestDetails();
            
          
            /// *** lend request effects *** ///
             LendRequest = ILendRequest_v1(_activeLendRequestAddress);
            address activeLender = LendRequest.i_lender();
            (uint256 amountLended, , , , ) = LendRequest.getLendRequestDetails();
           

              console.log("ran ",index+1,"times");
              console.log("_activeBorrowRequestAddress ",_activeBorrowRequestAddress);
              console.log("_activeLendRequestAddress ",_activeLendRequestAddress);
              
            // create active loan vault owners address array
            address[3] memory owners = [
                activeBorrower,
                activeLender,
                address(this)//change this later
            ];

            // deploys new active loan vault
            activeLoan _activeLoan = new activeLoan(
                owners,
                collateral,
                memeCoin,
                amountLended
            );

             
            /// *** effects *** ///
            s_settledBorrowRequest[address(_activeBorrowRequestAddress)] = index;
            s_settledLendRequest[address(_activeLendRequestAddress)] = index;
            // update mapping of borrower address to active active loan
            userToActiveLoanContract[address(activeBorrower)].push( address(_activeLoan));
            // update mapping of lender address to active active loan
            userToActiveLoanContract[address(activeLender)].push(address(_activeLoan));
            // update s_activeBorrowRequestAddress
            s_activeBorrowRequestAddress = _activeBorrowRequestAddress;
            // update s_activeLendRequestAddress
            s_activeLendRequestAddress = _activeLendRequestAddress;

            /// *** emits *** ///
            emit loanOfferExecuted(address(_activeLoan));
              
             /// *** interactions *** ///  
          
            BorrowRequest.acceptLoan(address(_activeLoan)); //transfers collateral from borrow request to active loan vault address.
            LendRequest.offerLoan(address(activeBorrower)); //transfers requested native token amount to borrowers address.
    }


    function _executionState(executionState state) internal {
        currentLoanState = state;
    }

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

    /// @notice This function returns the latest processed borrow request contract address.
    /// @return activeBorrowRequestAddress
    function getActiveBorrowRequestAddress() public view returns(address activeBorrowRequestAddress) {
        return s_activeBorrowRequestAddress; 
    }

    /// @notice This function returns the latest processed lend request contract address.
    function getActiveLendRequestAddress() public view returns(address activeLendRequestAddress) {
        return s_activeLendRequestAddress; 
    }


    /// @dev this function returns the address of the current limitMarket contract
    /// @return limitMarketContract the return variables of a contract’s function state variable
    function getLimitMarketContractAddress()
        public
        view onlyOwner
        returns (address limitMarketContract)
    {
        return s_limitMarketAddress;
    }
}
