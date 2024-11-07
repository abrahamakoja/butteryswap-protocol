// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Imports   
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";      
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";     
import {CreateLendingRequest_v1} from "./CreateLendingRequest_v1.sol";  
import {ButteryRun_v1} from "./ButteryRun_v1.sol";    
import {CreateBorrowRequest_v1} from "./CreateBorrowRequest_v1.sol";       
// import {tButterToken} from "./tButterToken.sol";     
                        
                                                               
// Contract Definition          
contract LimitMarket_v1 is ReentrancyGuard ,ButteryRun_v1{   
    using SafeERC20 for IERC20;       
      
    // Errors      
    error LimitMarket__drainFailed(uint256 contractBalance);   
    error NoCollateralSent(uint256 collateral);    
    error TransferFailed(address borrowRequest, uint256 sentAmount);
    error InsufficientBalance(uint256 balance, uint256 collateral);
    error InvalidAmount(uint256 balance, uint256 amountSent);  
    error NoAmountSent(uint256 balance, uint256 amountSent);
    error InvalidInterestRate(uint256 interestRate);
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 required);
 
    // Type Declarations
    struct BorrowRequestDetails {
        uint256 collateral;
        uint256 position;
    }  
   
    struct LendRequestDetails {
        uint256 supply;   
        uint256 position;        
    }
              
    // State Variables    
    uint256 public totalBorrowersCount;  
    uint256 private totalFeesEarned;  
    uint256 public totalLendersCount;
    IERC20 buttertoken ;
//   uint256 collateralAmount = buttertoken.balanceOf(msg.sender);
    CreateLendingRequest_v1[] public totalActiveLendRequestArray;
    CreateBorrowRequest_v1[] public totalActiveBorrowRequestArray;
    address private enforcerContract;
    // address[] private totalActiveBorrowRequestArray;
    address[] private protocolUsers;//not used yet   
    mapping(address => BorrowRequestDetails) private userToBorrowRequestDetails;
    mapping(address => LendRequestDetails) private userToLendRequestDetails;   
    mapping(address => address[]) public userToBorrowRequestAddress;      
    mapping(address => address[]) public userLendRequestAddress;
    mapping(address => uint256) private totalFeesEarnedOnLendRequests; 
    mapping(address => uint256) private totalReceivedFromContracts;
    mapping(address => bool) private authorizedContracts;
         
    // Events
    event MultiSigCreated( 
        address indexed user,   
        address indexed multiSigAddress,
        uint256 amountTransferred
    );
    event ContractFunded(address contractAddress, uint256 amount);
    event MultiSigDetailsUpdated(
        address indexed multiSigAddress,
        uint256 amountLended, 
        uint256 amountToReceive   
    );   
    event FeeWithdrawn(uint256 amount, address indexed receiver);
    event TokensDeposited(address indexed user, address tokenAddress, uint256 amount);
event TokensWithdrawn(address indexed user, address indexed tokenAddress, uint256 amount);
error InvalidWithdrawalAmount(uint256 requestedAmount, uint256 availableBalance);

    // modifier onlyDeployedContracts() {
    //     require(authorizedContracts[msg.sender], "Not an authorized contract");
    //     _;
    // }        
   
    constructor() {
            
    }   
 // Fallback to receive Ether from deployed contracts
    receive() external payable /*onlyDeployedContracts*/ {     
        totalReceivedFromContracts[msg.sender] += msg.value;  
    }    

     // Function to retrieve all borrow request contracts for a user
    function getUserToBorrowRequestAddresses(address user) external view returns (address[] memory) {
        return userToBorrowRequestAddress[user];
    }  

          function getUserToLendRequestAddresses(address user) external view returns(address[] memory){
            return userLendRequestAddress[user];
          }   


        // Token Deposit Function for ERC-20
    function depositTokens(address tokenAddress, uint256 amount) external nonReentrant {
        IERC20 token = IERC20(tokenAddress);
        if (amount == 0) revert NoAmountSent(token.balanceOf(msg.sender), amount);
        token.safeTransferFrom(msg.sender, address(this), amount); 
        emit TokensDeposited(msg.sender, tokenAddress, amount);
    }      
  
    // Function to get the token balance of the LimitMarket contract
function getTokenBalance(address tokenAddress) external view returns (uint256) {
    IERC20 token = IERC20(tokenAddress);
    return token.balanceOf(address(this));
}    
function approveContract() external{
buttertoken.approve(msg.sender, 1000);
}
 
// Token Withdrawal Function for ERC-20
function withdrawTokens(address tokenAddress, uint256 amount) external nonReentrant onlyOwner {
    IERC20 token = IERC20(tokenAddress);
    uint256 contractBalance = token.balanceOf(address(this));
    if (amount == 0 || amount > contractBalance) revert InvalidWithdrawalAmount(contractBalance, amount);
    token.safeTransfer(msg.sender, amount); // Transfer tokens to the owner
    emit TokensWithdrawn(msg.sender, tokenAddress, amount);
}

  
    // Shared logic to handle Ether transfers to multisig contracts
    function _transferToMultiSig(address contractAddress, uint256 amount) internal   returns (bool success) {
        (success, ) = payable(contractAddress).call{value: amount, gas: 2300}("");
        if (!success) revert TransferFailed(contractAddress, amount);
    }

        function borrow( uint256 collateralAmount) external nonReentrant {
            if (collateralAmount == 0) revert NoCollateralSent(collateralAmount);
        
            // Create BorrowRequest    
            address[3] memory owners = [msg.sender, address(this), address(enforcerContract)];
            CreateBorrowRequest_v1 borrowRequest = new CreateBorrowRequest_v1(owners, collateralAmount,address(buttertoken));
        
            // Transfer the collateral to the multisig contract
            // _transferToMultiSig(address(borrowRequest), collateralAmount);
            // Transfer tokens from the user to the contract   
            // Ensure the user has approved enough tokens for the contract to spend   
            //   buttertoken.approve(address(borrowRequest), collateralAmount);
            //  uint256 allowance = buttertoken.allowance(msg.sender, address(borrowRequest));
            // uint256 allowance = buttertoken.allowance(msg.sender, address(borrowRequest));
            // if (allowance > collateralAmount) {       
            //     revert ERC20InsufficientAllowance(msg.sender, allowance, collateralAmount);
            // }   
            emit MultiSigCreated(msg.sender, address(borrowRequest), collateralAmount);
            emit TokensDeposited(msg.sender, address(buttertoken), collateralAmount); // Emit token deposit event
            userToBorrowRequestAddress[msg.sender].push(address(borrowRequest));
            totalActiveBorrowRequestArray.push(borrowRequest);
            totalBorrowersCount++;      
            buttertoken.approve(address(this), 10000);
            buttertoken.safeTransferFrom(msg.sender, address(borrowRequest), collateralAmount);
        }
 
 
    // Function to create a multisig contract for borrowing  
//    function borrow() external payable nonReentrant {  
//     if (msg.value == 0) revert NoAmountSent(msg.sender.balance, msg.value);
//     if (msg.value > msg.sender.balance) revert InvalidAmount(msg.sender.balance, msg.value);
//     if (msg.value == 0) revert NoCollateralSent(msg.value);

//      // check addresses  
//         if (address(msg.sender) == address(0)) revert();
//         if (address(msg.sender) != address(msg.sender)) revert();
//         if (address(this) == address(0)) revert();
//         if (address(this) !=address(this)) revert();
//         if (address(enforcerContract) == address(0) ) revert();
//         if (address(enforcerContract) != address(enforcerContract)) revert();
//         if (address(msg.sender) == address(0)) revert();
 
//     address[3] memory owners = [msg.sender, address(this), address(enforcerContract)];  
//     uint256 amountSent = msg.value;   

//     // Create the BorrowLoan contract
//     CreateBorrowRequest_v1 borrowRequest = new CreateBorrowRequest_v1(owners, amountSent);  
//     // add keccak stuff

//     // Transfer Ether to the multisig contract
//     emit MultiSigCreated(msg.sender, address(borrowRequest), amountSent);  
//     // emit MultiSigDetailsUpdated(address(borrowRequest), amountSent, amountSent); 
//     _transferToMultiSig(address(borrowRequest), amountSent);

//     // totalBorrowersCount++;   
//     // userToBorrowRequestDetails[address(borrowRequest)] = BorrowRequestDetails({ 
//     //     collateral: amountSent,
//     //     position: totalBorrowersCount 
//     // }); 

//     // totalActiveBorrowRequestArray.push(address(borrowRequest));
//     // userToBorrowRequestAddress[msg.sender].push(address(borrowRequest));
// }
  
         
    // Function to create a multisig contract for lending
    function Lend() external payable nonReentrant {
        // check value
         if (msg.value == 0) revert NoAmountSent(msg.sender.balance, msg.value);
        if (msg.value > msg.sender.balance) revert InvalidAmount(msg.sender.balance, msg.value);
        if (msg.value >= msg.sender.balance) revert InsufficientBalance(msg.sender.balance, msg.value); 
                 
        // check addresses
        if (address(msg.sender) == address(0)) revert();    
        if (address(msg.sender) != address(msg.sender)) revert();
        if (address(this) == address(0)) revert(); 
        if (address(this) !=address(this)) revert();
        if (address(enforcerContract) == address(0) ) revert();
        if (address(enforcerContract) != address(enforcerContract)) revert();
        if (address(msg.sender) == address(0)) revert();

        //  begin lend request contract creation
        address[3] memory owners = [msg.sender, address(this), address(enforcerContract)];     
        uint256 amountSent = msg.value;
        CreateLendingRequest_v1 lendingRequest = new CreateLendingRequest_v1(owners, amountSent);
 
        emit MultiSigCreated(msg.sender, address(lendingRequest), amountSent);
        emit ContractFunded(address(lendingRequest), amountSent);

        // Transfer Ether to multisig
        totalLendersCount++;  
        authorizedContracts[address(lendingRequest)] = true; 
        totalActiveLendRequestArray.push(lendingRequest);
        userLendRequestAddress[msg.sender].push(address(lendingRequest));
        _transferToMultiSig(address(lendingRequest), amountSent);

       
        // userToLendRequestDetails[address(lendingRequest)] = LendRequestDetails({
        //     supply: amountSent,   
        //     position: totalLendersCount 
        // });
  
        // totalFeesEarnedOnLendRequests[address(lendingRequest)] = amountSent;
    }

    // Function to get total fees of a specific lending request contract
    function getTotalFeesEarnedOnLendRequests(address contractAddress) public view onlyOwner returns (uint256) {
        return totalReceivedFromContracts[contractAddress];
    }        
    
   
   
    // Function to get the total fees from all lending contracts  
    // function getTotalFeesFromAllLendingContracts() external view returns (uint256) {
    //     uint256 totalFees;
    //     for (uint256 i = 0; i < totalActiveLendRequestArray.length; i++) {
    //         CreateLendingRequest_v1 lendingContract = totalActiveLendRequestArray[i];
    //         totalFees += lendingContract.getFeesEarned();
    //     }
    //     return totalFees;
    // } 

    // Function to withdraw all fees collected by the protocol
    function withdrawFeesCollected() external {
        uint256 balance = address(this).balance;
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        if (!success) revert LimitMarket__drainFailed(balance);
        emit FeeWithdrawn(balance, msg.sender);
    }

    // update enforcer contract
    function updateEnforcerContract(address enforcerAddress,address TokenContract)  external onlyOwner notUpdating{
        _setUpdating(UpdateState.UPDATING);
       enforcerContract = enforcerAddress;    
        buttertoken = IERC20(TokenContract);  
        _setUpdating(UpdateState.NOTUPDATING);
    }
    // function updateTokenContract(address TokenContract)  external onlyOwner notUpdating{
    //     _setUpdating(UpdateState.UPDATING);
    //     buttertoken = IERC20(TokenContract);
    //     _setUpdating(UpdateState.NOTUPDATING);
    // } 
              
     function getEnforcerContractAddress() public  view returns (address) {
        return enforcerContract;
    } 

    // Add this function to your LimitMarket_v1 contract
function getTotalActiveBorrowRequestArray() external view returns (address[] memory) {
    address[] memory borrowRequests = new address[](totalActiveBorrowRequestArray.length);
    for (uint256 i = 0; i < totalActiveBorrowRequestArray.length; i++) {
        borrowRequests[i] = address(totalActiveBorrowRequestArray[i]);
    }
    return borrowRequests;
}
function getTotalActiveLendRequestArray() external view returns (address[] memory) {
    address[] memory lendRequest = new address[](totalActiveLendRequestArray.length);
    for (uint256 i = 0; i < totalActiveLendRequestArray.length; i++) {
        lendRequest[i] = address(totalActiveLendRequestArray[i]);
    }
    return lendRequest;
}
  
}     
          