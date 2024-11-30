// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
       
import {ButteryRun_v1} from "./ButteryRun_v1.sol";    
 
// import {CreateLendingRequest_v1} from "./CreateLendingRequest_v1.sol";    
   
interface ILimitMarket_v1 {
    function totalActiveBorrowRequestArray(uint256 index) external view returns (address);  
    function totalActiveLendRequestArray(uint256 index) external view returns (address);
    function totalBorrowersCount() external view returns (uint256);
    function totalLendersCount() external view returns (uint256);
} 
  
// old 1386436 1199996 1181592
// new 870675  751508  733104  
//     711354  612968  594564
 //    551247  473745  455341
   
interface ILendRequest_v1{  
    function cancelBorrowRequest() external ;   
    function lend(address,uint256) external;
}  
  
contract Enforcer_v1 is ButteryRun_v1 {   
      error LimitMarket__drainFailed(uint256 contractBalance);   
      
    address private limitMarketAddress;        
    ILimitMarket_v1 limitMarket; 

    // Constructor to set LimitMarket contract address
    constructor(/*address _limitMarketAddress*/) { 
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


    function executeWithdrawOnLendRequests(uint256 startIndex) external onlyOwner {
        uint256 totalLendRequests = limitMarket.totalLendersCount();   
        uint256 batchLimit = 10;
        uint256 endIndexLend = startIndex + batchLimit > totalLendRequests ? totalLendRequests : startIndex + batchLimit;

        // Loop through the lend requests and execute the function
        for (uint256 i = startIndex; i < endIndexLend; i++) {
            address lendRequestAddress = limitMarket.totalActiveLendRequestArray(i);
            ILendRequest_v1 lendRequest = ILendRequest_v1(lendRequestAddress);
            
            // Call the withdraw function 
            // get borrower address{refactor borrow request to match lend request}
            // move borrow and lend request to its own abstract contract and instead use an interface within limit to deploy{create borrow/lend}
            // create the new wallet between borower and lender
            //  integrate dex limit order on token
            lendRequest.lend(address(this), 1 ether);    
        }
}

   
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
