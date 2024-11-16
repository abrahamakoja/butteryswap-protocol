// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Imports  
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";      
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";  
import {CreateBorrowRequest_v1} from "./CreateBorrowRequest_v1.sol";
import {CreateLendingRequest_v1} from "./CreateLendingRequest_v1.sol";    
  
// Contract Definition
contract LimitMarket_v1 is ReentrancyGuard{
    using SafeERC20 for IERC20;
 
// Errors    
error LimitMarket__drainFailed(uint256 contractBalance);
error NoCollateralSent(uint256);
error TransferFailed(address borrowrequest, uint256 sentAmount);
error OnlyOwnerAllowed();  
error InsufficientBalance(uint256 balance, uint256 collateral);
error inValidAmount(uint256 balance, uint256 amountsent);
error NoAmountSent(uint256 balance, uint256 amountsent);
error InvalidInterestRate(uint256 interestRate);
   
// Type Declarations
struct borrowRequestDetails {
    uint256 depositedAmount;
    uint256 collateral;
 uint256 position;
    // add balance of tokens, address and any value to be used
}
// Type Declarations  
struct LendRequestDetails {
    uint256 supply;
 uint256 position;
    // add balance of tokens, address and any value to be used
}
    // State Variables
    uint256 public totalBorrowersCount;
    uint256 public totalFeesEarned;
    uint256 public totalLendersCount;
    CreateLendingRequest_v1[] public protol_TotalActiveLendRequest_Array; //total active borrow requests contract address in the protocol
    address[] public protol_TotalActiveBorrowRequest_Array;//total active borrow requests contract address in the protocol
    // address[] public protol_TotalActiveLendRequest_Array;//total active borrow requests contract address in the protocol
    address[] public protocolUsers;// list of all wallets interacting with buttery swap protocol || may move this smwhere else
    mapping(address => borrowRequestDetails) public userToBorrowRequestDetails; //stores a mapping of a specific user wallet address to the struct borrow request.
    // mapping(address => CreateLendingRequest_v1) public addressToLendingRequestsContract; //returns the contract abi via its address
    mapping(address => LendRequestDetails) public userToLenRequestDetails; //stores a mapping of a specific user wallet address to the struct borrow request.
    mapping(address => address[]) public userToBorrowRequestAddress; //stores a mapping of a specific user wallet address to all their borrow requests contract they made.
    mapping(address => address[]) public userLendRequestAddress; //stores a mapping of a specific user wallet address to all their borrow requests contract they made.
    mapping(address => uint256) public totalFeesEarnedOnLendRequests;
    // mapping(CreateLendingRequest_v1 => address) public lendingRequestToAddress;
    mapping(address => uint256) public totalReceivedFromContracts;
    mapping(address => bool) public authorizedContracts;




    // Events
    event MultiSigCreated(
        address indexed user,
        address indexed multiSigAddress,
        uint256 amountTransferred
    );
    event ContractFunded(address contractAddress, uint256 amount);
    event MultiSigDetailsUpdated(
        address indexed multiSigAddress,
        uint256 depositedAmount,
        uint256 amountToReceive   
    );   

modifier onlyDeployedContracts() {
    require(authorizedContracts[msg.sender], "Not an authorized contract");
    _;
}

    // add event for contract funded
    // Constructor
    constructor() { 
    }    

    // Function to create a multisig contract between this contract and the caller, and transfer Ether to the newly created multisig  
    function createBorrowRequest(uint256 _collateral) external payable nonReentrant {
        // Check the amount to send is valid  
        if (msg.value == 0) revert NoAmountSent(msg.sender.balance, msg.value);
        if (msg.value > msg.sender.balance) revert inValidAmount(msg.sender.balance, msg.value);
        if (_collateral == 0) revert NoCollateralSent(msg.value);
        if (_collateral >= msg.sender.balance) revert InsufficientBalance(msg.sender.balance, _collateral);

        //   effects 
        address[2] memory owners =[msg.sender,address(this)];
        uint256 _memeCoinAmountSent = msg.value;       
        CreateBorrowRequest_v1 borrowRequest = new CreateBorrowRequest_v1(owners,_memeCoinAmountSent);


            // interactions
          // withdraws memecoin amount            
        //  // Transfer the Ether to the multisig contract
        (bool success, ) = payable(address(borrowRequest)).call{       
            value: msg.value, gas: 2300   
        }("");   
        if (!success) revert TransferFailed(address(borrowRequest), msg.value);
    

        // // Emit events
        emit MultiSigCreated(msg.sender, address(borrowRequest), msg.value);
        emit MultiSigDetailsUpdated(address(borrowRequest), msg.value, _memeCoinAmountSent);
        totalBorrowersCount++;   
        //     // store values for borrow request parameters      
            userToBorrowRequestDetails[address(borrowRequest)] = borrowRequestDetails({
                depositedAmount: msg.value,
                collateral: _collateral,   
                position: totalBorrowersCount  
            });   

          
         protol_TotalActiveBorrowRequest_Array.push(address(borrowRequest));  
         userToBorrowRequestAddress[msg.sender].push(address(borrowRequest));         
    }                  
    // Function to create a multisig contract between this contract and the caller, and transfer Ether to the newly created multisig  
    function createLendRequest( uint256 _interestRate) external payable nonReentrant {

        // Check the amount to send is valid  
        if (msg.value == 0) revert NoAmountSent(msg.sender.balance, msg.value);
        if (msg.value > msg.sender.balance) revert inValidAmount(msg.sender.balance, msg.value);
        if (msg.value >= msg.sender.balance) revert InsufficientBalance(msg.sender.balance, msg.value);
        if (_interestRate < 5 || _interestRate > 10) revert InvalidInterestRate(_interestRate); 


        //   effects 
        address[2] memory owners = [msg.sender,address(this)];
        uint256 _memeCoinAmountSent = msg.value;       
        CreateLendingRequest_v1   LendingRequest = new CreateLendingRequest_v1(owners,_memeCoinAmountSent,_interestRate);
        emit MultiSigCreated(msg.sender, address(LendingRequest), msg.value);

            // interactions
        (bool success, ) = payable(address(LendingRequest)).call{       
            value: msg.value, gas: 2300   
        }("");  
      if (!success)  revert TransferFailed(address(LendingRequest), msg.value);

        emit ContractFunded(address(LendingRequest), msg.value);

        totalLendersCount++;   
    
    
            // Emit events
            // store values for borrow request parameters      
            userToLenRequestDetails[address(LendingRequest)] = LendRequestDetails({
                supply: msg.value,   
                position: totalLendersCount  
            });   

        emit MultiSigDetailsUpdated(address(LendingRequest), msg.value, _memeCoinAmountSent);
 
        authorizedContracts[address(LendingRequest)] = true;
         protol_TotalActiveLendRequest_Array.push(LendingRequest);    
         userLendRequestAddress[msg.sender].push(address(LendingRequest)); 
         totalFeesEarnedOnLendRequests[address(LendingRequest)] = msg.value;
    }                  
          
        //  funtion to get total fees of specific borrow request contracts
        function getTotalFeesEarnedOnLendRequests( address lendRequestContractAddress) public view returns(uint256){
            totalReceivedFromContracts[lendRequestContractAddress];
            // CreateLendingRequest_v1   _LendingRequest = CreateLendingRequest_v1(protol_TotalActiveLendRequest_Array[index]);
            //  CreateLendingRequest_v1   _LendingRequest = CreateLendingRequest_v1(protol_TotalActiveLendRequest_Array);
            return   totalReceivedFromContracts[lendRequestContractAddress];
        }


    // Function to retrieve all borrow request contracts for a user      
    function getUserToBorrowRequest_Addresses(address user)  
        external          
        view     
        returns (address[] memory)            
    {      
        return userToBorrowRequestAddress[user];
    } 

    // Function to check the contract's balance
    function getBalance() public view returns (uint256) {
     
        return address(this).balance; 
    }

    // Function to check the contract's balance
    function getDeployedContractBalance(address borrowRequestAddress) public view returns (uint256 ) {
     
        return address(borrowRequestAddress).balance; 
    }
// gets all fees from lendRequest
    function getTotalFeesFromAllLendingContracts() external view returns (uint256) {
    uint256 totalFees;
    
    // Loop through all deployed lending request contracts and sum up their fees
    for (uint256 i = 0; i < protol_TotalActiveLendRequest_Array.length; i++) {
        CreateLendingRequest_v1 lendingContract = protol_TotalActiveLendRequest_Array[i];
        totalFees += lendingContract.getFeesEarned();
    }
    
    return totalFees;
}


    function withdrawFeesCollected() external {
      (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        if (!success) revert LimitMarket__drainFailed( address(this).balance);
    }

     receive() external payable onlyDeployedContracts{
        //   recieves fees from deployed loan contracts
         totalReceivedFromContracts[msg.sender] += msg.value;
    }
}
