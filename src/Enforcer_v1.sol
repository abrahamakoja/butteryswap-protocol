// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
       
import {ButteryRun_v1} from "./ButteryRun_v1.sol";     
import {LoanRequest} from "./LoanRequest.sol";
import {activeLoan} from "./activeLoan.sol";  
 
    
interface ILimitMarket_v1 {
    function totalActiveBorrowRequestArray(uint256 index) external view returns (address);  
    function totalActiveLendRequestArray(uint256 index) external view returns (address);
    function totalBorrowersCount() external view returns (uint256);
    function totalLendersCount() external view returns (uint256);  
}           
       
interface IBorrowRequest_v1{     
    function Owners(uint256 index) external view returns (address );           
    function acceptLoan(address) external;  
    function getBorrowRequestDetails() external view returns (
    address memeCoin, 
    uint256 collateral, 
    address[3] memory owners, 
    uint256 balanceMinusFee, 
    uint256 feeEarned, 
    LoanRequest.RequestState state
);
}   
interface ILendRequest_v1{     
   function s_lender() external view returns (address);            
    function offerLoan(address) external;
    function getLendRequestDetails() external view returns (
        uint256 amountLended, 
        address[3] memory owners, 
        uint256 balanceMinusFee,   
        uint256 feeEarned, 
        LoanRequest.RequestState state
    );
}  
  
contract Enforcer_v1 is ButteryRun_v1 {  


      error executeLoanFailed();
      error LimitMarket__drainFailed(uint256 contractBalance);
    //   owners,collateral,memeCoin,amountLended
      event executeLoan(address[3] owners, uint256 collateral, address memeCoin, uint256 amountLended);    
      event MultiSigCreated(       
    // /*    address indexed user,
        address indexed multiSigAddress
        // uint256 amountTransferred*/
    );  

    // activeLoan[] public activeLoans;
    mapping(address => address[]) private userToActiveBorrowContract;      
    mapping(address => address[]) private userActiveLendRequestContract; 
    // mapping(address => uin256) public walletToAmountBorrowed; 
   
    //  struct UserLoans {
    //     activeLoan[] activeBorrowLoans; // Array of active borrow loans
    //     activeLoan[] activeLendLoans;   // Array of active lend loans
    // }

    

    using LoanRequest for LoanRequest.BorrowRequest;
     LoanRequest.BorrowRequest private s_borrowRequest;  
    // solve from here
    using LoanRequest for LoanRequest.LendRequest;
    LoanRequest.LendRequest private s_lendRequest;   

    address private limitMarketAddress;         
    ILimitMarket_v1 limitMarket;   
             
    // Constructor to set LimitMarket contract address
    constructor(/*address _limitMarketAddress*/) { 
    //      address _limitMarket = 0x7798A400cBe0Ca14a7D614ECa1CD15adE5055413;
    //    limitMarketAddress = _limitMarket;  
        // limitMarketAddress = _limitMarketAddress; 
        // limitMarket = ILimitMarket_v1(_limitMarketAddress);
    }                          
       receive() external payable {}        
    // update enforcer contract 
    function updateLimitMarketContract(address _limitMarketAddress)  external onlyOwner notUpdating{
        _setUpdating(UpdateState.UPDATING); 
       limitMarketAddress = _limitMarketAddress;    
       limitMarket = ILimitMarket_v1(_limitMarketAddress);  
        _setUpdating(UpdateState.NOTUPDATING);            
    }                                 
              
    function getLimitMarketContractAddress() public  view returns (address) {
        return limitMarketAddress;    
    }

    // get the array of lend and borrow request
    // loop through each batch and call a transfer function on each contract
    // get the active index and creates a new multisig address between the borrower, the lender and the enforcer contract
    // transfer requested sol from lend request to the borrower address
    // transfer meme coin to the newly created multi sig address

//   do a refactor later for active request to pending request  
    function executeWithdrawOnLendRequests(uint256 startIndex) external   onlyOwner {
         uint256 totalBorrowRequests = limitMarket.totalBorrowersCount();
         uint256 totalLendRequests = limitMarket.totalLendersCount(); 
        uint256 batchLimit = 10;
        uint256 endIndexBorrow = startIndex + batchLimit > totalBorrowRequests ? totalBorrowRequests : startIndex + batchLimit;
        uint256 endIndexLend = startIndex + batchLimit > totalLendRequests ? totalLendRequests : startIndex + batchLimit;
        

        // gets and store the requst in a fixed number
        address[] memory borrowRequests = new address[](endIndexBorrow - startIndex);
        address[] memory lendRequests = new address[](endIndexLend - startIndex);
        

        // Loop through the lend requests and execute the function in 10 batches
        for (uint256 i = startIndex; i < endIndexLend; i++) {  
            // starts from 0 and increments
             borrowRequests[i - startIndex] = limitMarket.totalActiveBorrowRequestArray(i);
              lendRequests[i - startIndex] = limitMarket.totalActiveLendRequestArray(i);
 
            address activeBorrowRequestAddress = limitMarket.totalActiveBorrowRequestArray(i);
            IBorrowRequest_v1 BorrowRequest =  IBorrowRequest_v1(activeBorrowRequestAddress);
            address activeBorrower =  BorrowRequest.Owners(0);
            // get borrow request details
           (address memeCoin,uint256 collateral, , , , )  =  BorrowRequest.getBorrowRequestDetails();

            

            address activeLendRequestAddress = limitMarket.totalActiveLendRequestArray(i);
            ILendRequest_v1 LendRequest = ILendRequest_v1(activeLendRequestAddress);
            address activeLender =  LendRequest.s_lender(); 
            (uint256 amountLended , , , , )  =  LendRequest.getLendRequestDetails();
 
            // Call the withdraw function  
            // get borrower address{refactor borrow request to match lend request}
            // move borrow and lend request to its own abstract contract and instead use an interface within limit to deploy{create borrow/lend}
            // create the new wallet between borower and lender
            //  integrate dex limit order on token
           address[3] memory owners = [activeBorrower,activeLender,address(this)];
            activeLoan _activeLoan =  new activeLoan(owners,collateral,memeCoin , amountLended);  
            // LoanRequest.executeLoan(address(_activeLoan));
            // LoanRequest.executeLoan(s_borrowRequest,activeBorrowRequestAddress,address(_activeLoan));
           
              
            //  _executeLoan(activeBorrowRequestAddress,address(_activeLoan));
            // userToActiveLoans[]
           
  
            //   activeLoans.push(_activeLoan);
            // userLoans[activeBorrower].activeBorrowLoans.push(_activeLoan); // Update the borrow loans for the borrower
            // userLoans[activeLender].activeLendLoans.push(_activeLoan); 
            userToActiveBorrowContract[address(activeBorrower)].push(address(_activeLoan));
            userActiveLendRequestContract[address(activeLender)].push(address(_activeLoan));
            // walletToAmountBorrowed[address(activeBorrower)].push(depositedAmount);
            
            BorrowRequest.acceptLoan(address(_activeLoan));    //transfer memcoin to new multisign
            LendRequest.offerLoan(address(activeBorrower));     //transfers requested native token amount to borrower
            emit executeLoan(owners,collateral,memeCoin,amountLended);
            emit MultiSigCreated(address(_activeLoan));
        }  
}     

//  function getUserLoans(address user) external view returns (UserLoans memory) {
//         return userLoans[user]; // Retrieve all loans for the specified user
//     }
 
function getUserActiveLendContracts(address user) external view returns (address[] memory) {
        return userActiveLendRequestContract[user]; // Retrieve active lend contracts for the specified user
    }

    function getUserActiveBorrowContracts(address user) external view returns (address[] memory) {
        return userToActiveBorrowContract[user]; // Retrieve active borrow contracts for the specified user
    }

    // function getUserActiveLoans(address user) external view returns (activeLoan[] memory) {
    //     return activeLoans[user]; // Retrieve active loans for the specified user
    // }
    // only owner should be allowed in this this has to be external read from both the lend or borrow request
   // LendRequest storage _lendRequest, BorrowRequest storage _borrowRequest,address activeLoanAddress, uint256 loanAmount
//      function _executeLoan(address activeBorrowRequest,address activeLoanAddress) external  {
//      try  LoanRequest.executeLoan(s_borrowRequest,activeBorrowRequest,activeLoanAddress){
//         emit executeLoan(activeBorrowRequest);
//       }
//       catch {
//     revert executeLoanFailed();
//    }
//     }

    
    // Function to fetch 10 lend and borrow requests at a time in batches
    function batchFetchRequests(uint256 startIndex) external view returns (address[] memory _borrowRequests, address[] memory _lendrequest) {
        uint256 totalBorrowRequests = limitMarket.totalBorrowersCount();
        uint256 totalLendRequests = limitMarket.totalLendersCount(); 
        uint256 batchLimit = 10;
        uint256 endIndexBorrow = startIndex + batchLimit > totalBorrowRequests ? totalBorrowRequests : startIndex + batchLimit;
        uint256 endIndexLend = startIndex + batchLimit > totalLendRequests ? totalLendRequests : startIndex + batchLimit;

        address[] memory borrowRequests = new address[](endIndexBorrow - startIndex);
        address[] memory lendRequests = new address[](endIndexLend - startIndex);

        for (uint256 i = startIndex; i < endIndexBorrow; i++) {
            borrowRequests[i - startIndex] = limitMarket.totalActiveBorrowRequestArray(i);
        }  

        for (uint256 i = startIndex; i < endIndexLend; i++) {
            lendRequests[i - startIndex] = limitMarket.totalActiveLendRequestArray(i);
        }
        
       
        return (borrowRequests, lendRequests);
    }

    // Function to withdraw all fees collected by the protocol
    function withdrawFeesCollected() external {
        uint256 balance = address(this).balance;
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        if (!success) revert LimitMarket__drainFailed(balance);
        // emit FeeWithdrawn(balance, msg.sender);
    }  

      // Fallback function to accept Ether
 
}
 