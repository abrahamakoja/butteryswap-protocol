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
 * @author Butteryswap Protocol
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
import {LoanConfigLibrary} from "./libraries/LoanConfigLibrary.sol";
import {activeLoan} from "./activeLoan.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

////////////////////
/// Interfaces ///
/////////////////

// LimitMarket contract interface
interface ILimitMarket_v1 {

    function getPrioritizedBorrowRequestAddress(
        uint256 batchLimit,
        uint256 numOfResponse
    ) external view returns (address[] memory prioritizedLoans);
    function getTotalActiveBorrowRequestContractCount() external view returns(uint256);

     function getActiveBorrowRequestViaLimit(
        uint256 _startIndex,
        uint256 _numberOfResponse,
        uint256 _batchLimit
    ) external view returns (address[] memory borrowRequests);

    function getPrioritizedLendRequestAddress(
        uint256 batchLimit,
        uint256 numOfResponse
    ) external view returns (address[] memory prioritizedLoans);
    function getTotalActiveLendRequestContractCount() external view returns (uint256);

    function getActiveLendRequestViaLimit(
        uint256 _startIndex,
        uint256 _numberOfResponse,
        uint256 _batchLimit
    ) external view returns (address[] memory lendRequests);
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
            LoanConfigLibrary.RequestState state
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
            LoanConfigLibrary.RequestState state
        );
}

// Enforcer_v1 Contract Definition
contract Enforcer_v1 is Script, ButteryRun_v1, ReentrancyGuard, Ownable  {

    ///////////////
    /// Errors ///
    /////////////   
    
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
    uint256 private s_priorityBorrowCount;
    uint256 private s_priorityLendCount;
    address private s_activeBorrowRequestAddress; //keep track of the latest borrow request being processed.
    address private s_activeLendRequestAddress; //keep track of the latest lend request being processed.
    mapping(address => address[]) private userToActiveLoanContract;
    mapping(address borrowRequest => uint256 index) private s_settledBorrowRequest; // 
    mapping(address borrowRequest => uint256 index) private s_settledLendRequest; // 
    uint256 private constant BATCH_LIMIT = 10;
    uint256 private constant NUMBER_OF_RESPONSE = 1;
    
    //  address[]  borrowRequests;
        /// @dev gets and store the lend requests in a fixed number less than or equal to the batch limit
    //  address[]  lendRequests;
    // uint256 totalBorrowRequests;
    // uint256 totalLendRequests;
    // address[] prioritizedBorrowRequest;
    // address[] prioritizedLendRequest ;

   
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

    function _getLoanRequestDetails() internal view returns( uint256 _totalBorrowRequests,uint256 _totalLendRequests,address[] memory _prioritizedBorrowRequest,address[] memory  _prioritizedLendRequest,address[] memory  _borrowRequests,  address[] memory  _lendRequests){
           _totalBorrowRequests = limitMarket.getTotalActiveBorrowRequestContractCount();
           _totalLendRequests = limitMarket.getTotalActiveLendRequestContractCount();
         _prioritizedBorrowRequest = limitMarket.getPrioritizedBorrowRequestAddress(BATCH_LIMIT,NUMBER_OF_RESPONSE);
           _prioritizedLendRequest = limitMarket.getPrioritizedLendRequestAddress(BATCH_LIMIT,NUMBER_OF_RESPONSE);  
          _borrowRequests = limitMarket.getActiveBorrowRequestViaLimit(s_startingBorrowRequestIndex,_totalBorrowRequests,BATCH_LIMIT);
        /// @dev gets and store the lend requests in a fixed number less than or equal to the batch limit
         _lendRequests = limitMarket.getActiveLendRequestViaLimit(s_startingLendRequestIndex,_totalLendRequests,BATCH_LIMIT);
          return (_totalBorrowRequests,_totalLendRequests,_prioritizedBorrowRequest,_prioritizedLendRequest,_borrowRequests,_lendRequests);
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

    uint256  totalBorrowRequests;
    uint256  totalLendRequests;
    address[] memory prioritizedBorrowRequest;
    address[] memory prioritizedLendRequest;
    address[] memory  borrowRequests;
    address[] memory  lendRequests;

    (totalBorrowRequests,totalLendRequests,prioritizedBorrowRequest,prioritizedLendRequest,borrowRequests,lendRequests) = _getLoanRequestDetails();

        /// @dev check if liquidity is sufficient to settle loans, if loan requests are less than 1 on either sides ie;(borrow/lend), revert with the error Enforcer_v1_insufficientLiquidity
        if ((totalBorrowRequests == 0 ||  prioritizedLendRequest.length == 0) && (prioritizedBorrowRequest.length == 0 || totalLendRequests == 0)) {
            revert Enforcer_v1_insufficientLiquidity();
            }

    uint256 lowestRequestsCount = totalBorrowRequests <  totalLendRequests ? totalBorrowRequests: totalLendRequests;
    uint256 batchLimit = lowestRequestsCount < BATCH_LIMIT ? lowestRequestsCount : BATCH_LIMIT ; //ensure the batch limit of 10 is not exceeded for the endIndexLend variable
       
       if((totalBorrowRequests > 1 || totalLendRequests > 1)){
        for (uint256 i = 0; i < batchLimit; i++) {
            /// @dev this Loops through the loan requests and execute the offerLoan & acceptLoan functions, this would be done in batches of 10 at a time.
            address _activeBorrowRequestAddress =  borrowRequests[i];
            address _activeLendRequestAddress = lendRequests[i];
           
            _processLoan(_activeBorrowRequestAddress,_activeLendRequestAddress,i);
        }
     }
        // handle priority loans  
       _prioritizedBorrowLoan();
       _prioritizedLendLoan();

    s_batchCount++;
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
    function _prioritizedBorrowLoan() internal {
            (,uint256 totalLendRequests,,address[] memory _prioritizedBorrowRequest,, address[] memory _lendRequests) = _getLoanRequestDetails();
            if (_prioritizedBorrowRequest.length == 0) {
                 return ;
            }
            if(totalLendRequests == 0)
            {
                return;
                }
                
            uint256 limit = totalLendRequests > _prioritizedBorrowRequest.length ? _prioritizedBorrowRequest.length : totalLendRequests;
    
            for (uint256 i = 0; i < limit; i++) { 

                   address _activeBorrowRequestAddress =  _prioritizedBorrowRequest[i];
                   address _activeLendRequestAddress = _lendRequests[i];
                _processLoan(_activeBorrowRequestAddress,_activeLendRequestAddress,i); 
               
            }
                s_priorityBorrowCount++;
    }

    function _prioritizedLendLoan() internal {
            (uint256 totalBorrowRequests,,,address[] memory _prioritizedLendRequest,address[] memory borrowRequests,) =_getLoanRequestDetails();
           
            if (_prioritizedLendRequest.length == 0){
                return;
            } 
            if ( totalBorrowRequests == 0) {
                return;
            }
           
            for (uint256 i = 0; i < _prioritizedLendRequest.length; i++) { 
                if(i == NUMBER_OF_RESPONSE){
                    break;
                }else{
                _processLoan(borrowRequests[i],_prioritizedLendRequest[i],i); 
               
                }
            }
             s_priorityLendCount++;
         
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
 /// @return adress[]: array of active loan addresses
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
