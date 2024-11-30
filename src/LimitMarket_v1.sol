// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Imports  
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";      
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";     
// import {CreateBorrowRequest_v1} from "./CreateBorrowRequest_v1.sol";
import {CreateLendingRequest_v1} from "./CreateLendingRequest_v1.sol";  
import {ButteryRun_v1} from "./ButteryRun_v1.sol";    
import {Loan} from "./Loan.sol";


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
 
    // Type Declarations
    struct BorrowRequestDetails {
        uint256 depositedAmount;
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
    CreateLendingRequest_v1[] public totalActiveLendRequestArray;
    address private s_enforcer_v1;
    address[] public totalActiveBorrowRequestArray;
    address[] private protocolUsers;//not used yet   
    mapping(address => BorrowRequestDetails) public userToBorrowRequestDetails;
    mapping(address => LendRequestDetails) public userToLendRequestDetails;
    mapping(address => address[]) public userToBorrowRequestAddress;
    mapping(address => address[]) public userLendRequestAddress;
    mapping(address => uint256) public totalFeesEarnedOnLendRequests;
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
    event FeeWithdrawn(uint256 amount, address indexed receiver);

    modifier onlyDeployedContracts() {
        require(authorizedContracts[msg.sender], "Not an authorized contract");
        _;
    }

    constructor() {
      
    }

    // Shared logic to handle Ether transfers to multisig contracts
    function _transferToMultiSig(address contractAddress, uint256 amount) private onlyOwner returns (bool success) {
        (success, ) = payable(contractAddress).call{value: amount, gas: 2300}("");
        if (!success) revert TransferFailed(contractAddress, amount);
    }
    //  function createOldBorrowRequest(uint256 _collateral) external payable nonReentrant {
    //     if (msg.value == 0) revert NoAmountSent(msg.sender.balance, msg.value);
    //     if (msg.value > msg.sender.balance) revert InvalidAmount(msg.sender.balance, msg.value);
    //     if (_collateral == 0) revert NoCollateralSent(_collateral);
    //     if (_collateral >= msg.sender.balance) revert InsufficientBalance(msg.sender.balance, _collateral);

    //     address[3] memory owners = [msg.sender, address(this),address(s_enforcer_v1)];
    //     uint256 amountSent = msg.value;
    //     CreateBorrowRequest_v1 borrowRequest = new CreateBorrowRequest_v1(owners, amountSent);

    //     // Transfer Ether to multisig
    //     _transferToMultiSig(address(borrowRequest), amountSent);
    //     emit MultiSigCreated(msg.sender, address(borrowRequest), amountSent);
    //     emit MultiSigDetailsUpdated(address(borrowRequest), amountSent, amountSent);

    //     totalBorrowersCount++;
    //     userToBorrowRequestDetails[address(borrowRequest)] =
    //         BorrowRequestDetails({depositedAmount: amountSent, collateral: _collateral, position: totalBorrowersCount});

    //     totalActiveBorrowRequestArray.push(address(borrowRequest));
    //     userToBorrowRequestAddress[msg.sender].push(address(borrowRequest));
    // }

    // Function to create a multisig contract for borrowing  
    function borrow(uint256 _collateral) external payable nonReentrant {
        if (msg.value == 0) revert NoAmountSent(msg.sender.balance, msg.value);
        if (msg.value > msg.sender.balance) revert InvalidAmount(msg.sender.balance, msg.value);
        if (_collateral == 0) revert NoCollateralSent(_collateral);
        if (_collateral >= msg.sender.balance) revert InsufficientBalance(msg.sender.balance, _collateral);
 
       
        address[3] memory owners = [msg.sender, address(this), address(s_enforcer_v1)];  
        uint256 amountSent = msg.value;   
        Loan borrowRequest = new Loan(owners, _collateral); 
      
        // Transfer Ether to multisig 
        emit MultiSigCreated(msg.sender, address(borrowRequest), amountSent);
        emit MultiSigDetailsUpdated(address(borrowRequest), amountSent, amountSent); 
        _transferToMultiSig(address(borrowRequest), amountSent);

        totalBorrowersCount++;
        userToBorrowRequestDetails[address(borrowRequest)] = BorrowRequestDetails({ 
            depositedAmount: amountSent,
            collateral: _collateral,
            position: totalBorrowersCount
        });

        totalActiveBorrowRequestArray.push(address(borrowRequest));
        userToBorrowRequestAddress[msg.sender].push(address(borrowRequest));
    }     
         
    // Function to create a multisig contract for lending
    function createLendRequest(uint256 _interestRate) external payable nonReentrant {
        // check value
        if (msg.value == 0) revert NoAmountSent(msg.sender.balance, msg.value);
        if (msg.value > msg.sender.balance) revert InvalidAmount(msg.sender.balance, msg.value);
        if (msg.value >= msg.sender.balance) revert InsufficientBalance(msg.sender.balance, msg.value); 
        if (_interestRate < 5 || _interestRate > 10) revert InvalidInterestRate(_interestRate);
    
        // check addresses
        if (address(msg.sender) == address(0)) revert();
        if (address(msg.sender) != address(msg.sender)) revert();
        if (address(this) == address(0)) revert();
        if (address(this) !=address(this)) revert();
        if (address(s_enforcer_v1) == address(0) ) revert();
        if (address(s_enforcer_v1) != address(s_enforcer_v1)) revert();
        if (address(msg.sender) == address(0)) revert();

        //  begin lend request contract creation
        address[3] memory owners = [msg.sender, address(this), address(s_enforcer_v1)];     
        uint256 amountSent = msg.value;
        CreateLendingRequest_v1 lendingRequest = new CreateLendingRequest_v1(owners, amountSent, _interestRate);
 
        // Transfer Ether to multisig
        _transferToMultiSig(address(lendingRequest), amountSent);

        emit MultiSigCreated(msg.sender, address(lendingRequest), amountSent);
        emit ContractFunded(address(lendingRequest), amountSent);
   
        totalLendersCount++;  
        userToLendRequestDetails[address(lendingRequest)] = LendRequestDetails({
            supply: amountSent,   
            position: totalLendersCount 
        });

        authorizedContracts[address(lendingRequest)] = true; 
        totalActiveLendRequestArray.push(lendingRequest);
        userLendRequestAddress[msg.sender].push(address(lendingRequest));
        totalFeesEarnedOnLendRequests[address(lendingRequest)] = amountSent;
    }

    // Function to get total fees of a specific lending request contract
    function getTotalFeesEarnedOnLendRequests(address lendRequestContractAddress) public view onlyOwner returns (uint256) {
        return totalReceivedFromContracts[lendRequestContractAddress];
    }       
   
    // Function to retrieve all borrow request contracts for a user
    function getUserToBorrowRequestAddresses(address user) external view returns (address[] memory) {
        return userToBorrowRequestAddress[user];
    }

    // Function to get the total fees from all lending contracts
    function getTotalFeesFromAllLendingContracts() external view returns (uint256) {
        uint256 totalFees;
        for (uint256 i = 0; i < totalActiveLendRequestArray.length; i++) {
            CreateLendingRequest_v1 lendingContract = totalActiveLendRequestArray[i];
            totalFees += lendingContract.getFeesEarned();
        }
        return totalFees;
    } 

    // Function to withdraw all fees collected by the protocol
    function withdrawFeesCollected() external {
        uint256 balance = address(this).balance;
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        if (!success) revert LimitMarket__drainFailed(balance);
        emit FeeWithdrawn(balance, msg.sender);
    }

    // update enforcer contract
    function updateEnforcerContract(address enforcer_v1)  external onlyOwner notUpdating{
        _setUpdating(UpdateState.UPDATING);
       s_enforcer_v1 = enforcer_v1;  
        _setUpdating(UpdateState.NOTUPDATING);
    }

     function getEnforcerContractAddress() public  view returns (address) {
        return s_enforcer_v1;
    }
 
    // Fallback to receive Ether from deployed contracts
    receive() external payable onlyDeployedContracts {
        totalReceivedFromContracts[msg.sender] += msg.value;  
    }

  
}
