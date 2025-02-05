// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//  debug
import {Script, console} from "forge-std/Script.sol";

////////////////
/// Imports ///
//////////////

import {BorrowRequest_v1} from "./BorrowRequest_v1.sol";
import {erc20TokenLibrary} from "./erc20TokenLibrary.sol";

///////////////////
/// Interfaces ///
/////////////////

interface ISupportedTokens {
    function checkTokenIsApproved(address token) external view returns (bool);
}

contract BorrowRequestFactory {

    ////////////////
    /// Errors ///
    //////////////

    error BorrowRequestFactory_unSupportedToken(address token);
    error BorrowRequestFactory_TransferFailed(
        address borrowRequest,
        uint256 sentAmount
    );
    error BorrowRequestFactory_InsufficientBalance(
        uint256 balance,
        uint256 collateral
    );
    error BorrowRequestFactory_InvalidAmount(
        uint256 balance,
        uint256 amountSent
    );
    error BorrowRequestFactory_NoAmountSent(
        uint256 balance,
        uint256 amountSent
    );
    error UnauthorizedAccess(address caller);
    error BorrowRequestFactory_InvalidTokenCount(uint256 tokenCount);
    error BorrowRequestFactory_NoCollateralSent(uint256 collateralAmount);
    error BorrowRequestFactory_InsufficientAllowance(
        address token,
        uint256 allowance,
        uint256 requiredAmount
    );

    /////////////////////////
    /// Type Declarations ///
    ///////////////////////

    using erc20TokenLibrary for erc20TokenLibrary.tokenData;

    /////////////////////////
    /// State variables ///
    ///////////////////////

    BorrowRequest_v1[] public totalBorrowRequestArray;
    ISupportedTokens supportedTokensContract;
    mapping(address => address[]) public userToBorrowRequestAddress;
     mapping(address loanRequest => bool prioritized)private s_loanIsPrioritized;

    //////////////
    /// Events ///
    ////////////

    event BorrowRequestCreated(
        address indexed user,
        address indexed multiSigAddress,
        uint256 amountTransferred
    );


    //////////////////
    /// Functions ///
    ////////////////

    constructor(address supportedTokensAddress) {
        supportedTokensContract = ISupportedTokens(supportedTokensAddress);
    }

    ////////////////////////
    ///External Functions ///
    ////////////////////////
    
    function _approveToken(address token, address spender, uint256 amount) internal {
     // Reset the allowance to the exact collateralAmount

      console.log("msg.sender",msg.sender);
      console.log("address this",address(this));
        erc20TokenLibrary.approveTokens(
            token,
            address(spender),
            amount
        );
    }

    /// @notice Creates a new BorrowRequest instance
    /// @param _collateralAmount The amount of collateral to be locked
    /// @param _tokens The list of tokens to be used as collateral
    /// @param _owners The address of the enforcer contract
    /// @param _priority The address of the enforcer contract
    function createBorrowRequest(
        uint256 _collateralAmount,
        address[] calldata _tokens,  
         address[2] calldata _owners,
         bool _priority
    ) external {
       
       
     rawCreateBorrowRequest(
            _collateralAmount,
            _tokens,
            _owners,
            _priority
        );
    }

    /// @notice Internal function to create a new BorrowRequest_v1 instance
    /// @param collateralAmount The amount of collateral to be locked
    /// @param tokens The list of tokens to be used as collateral
    /// @param owners The address of the enforcer contract
    /// @param priority The address of the enforcer contract
   function rawCreateBorrowRequest(
    uint256 collateralAmount,
    address[] calldata tokens,
    address[2] calldata owners,
    bool priority
) internal {
    // checks
    if (tokens.length == 0 || tokens.length > 3)
        revert BorrowRequestFactory_InvalidTokenCount(tokens.length);
    if (collateralAmount == 0)
        revert BorrowRequestFactory_NoCollateralSent(collateralAmount);

    for (uint256 index = 0; index < tokens.length; index++) {
        if (!supportedTokensContract.checkTokenIsApproved(tokens[index])) 
            revert BorrowRequestFactory_unSupportedToken(tokens[index]);
        
        // Reset the allowance to the exact collateralAmount
        erc20TokenLibrary.approveTokens(
            tokens[index],
           address(this),
            collateralAmount
        );
    }

    // effects
    BorrowRequest_v1 BorrowRequest = new BorrowRequest_v1(
        owners,
        collateralAmount,
        tokens,
        block.timestamp
    );

    // check and update priority
    if (priority) {
        s_loanIsPrioritized[address(BorrowRequest)] = true;
    }

    totalBorrowRequestArray.push(BorrowRequest);
    userToBorrowRequestAddress[msg.sender].push(address(BorrowRequest));

    emit BorrowRequestCreated(
        msg.sender,
        address(BorrowRequest),
        collateralAmount
    );

    // interactions
    for (uint256 index = 0; index < tokens.length; index++) {
        erc20TokenLibrary.transferFromTokens(
            tokens[index],
            address(owners[0]),
            address(BorrowRequest),
            collateralAmount
        );
    }
}

    ////////////////////////////////////////////////
    /// External & Public View & Pure Functions ///
    //////////////////////////////////////////////

     // Function to retrieve all borrow request contracts for a user // legacy
    function getUserToBorrowRequestAddresses(
        address user
    ) external view returns (address[] memory) { 
        return userToBorrowRequestAddress[user];
    }

    // @dev returns the total active borrow requests addresses.
    function getTotalActiveBorrowRequestContractAddresses()
        public
        view
        returns (address[] memory)
    {
        address[] memory borrowRequest = new address[](
            totalBorrowRequestArray.length
        );
        uint256 counter = 0;
        for (uint256 i = 0; i < totalBorrowRequestArray.length; i++) {
            BorrowRequest_v1 borrowRequest_v1 = BorrowRequest_v1(
                payable(address(totalBorrowRequestArray[i]))
            );
            uint8 status = uint8(borrowRequest_v1.getRequestState());
            if (status != 0) {
                continue;
            }
            borrowRequest[counter] = address(totalBorrowRequestArray[i]);
            counter++;
        }

        address[] memory activeBorrowRequest = new address[](counter);
        for (uint256 i = 0; i < counter; i++) {
            activeBorrowRequest[i] = borrowRequest[i];
        }

        return activeBorrowRequest;
    }

    // @dev returns the specific index of an active borrow requests within the array of active borrow request.
    function getBorrowRequestPositionOnActiveRequestQue(
        address borrowRequest
    ) public view returns (uint256 position) {
        address[]
            memory borrowRequests = getTotalActiveBorrowRequestContractAddresses();
        for (uint256 i = 0; i < borrowRequests.length; i++) {
            if (borrowRequests[i] == address(borrowRequest)) {
                position = i + 1;
            }
        }
        return position;
    }

    // @dev returns the specific index of an active borrow requests within the array of active borrow request.
    function getActiveBorrowRequestContractAddressViaIndex(
        uint256 index
    ) public view returns (address borrowRequest) {
        address[]
            memory borrowRequests = getTotalActiveBorrowRequestContractAddresses();
        address targetBorrowRequestContract;
        for (uint256 i = 0; i < borrowRequests.length; i++) {
            if (borrowRequests[i] == borrowRequests[index]) {
                targetBorrowRequestContract = address(borrowRequests[i]);
            }
        }
        return targetBorrowRequestContract;
    }

    // // returns specific number of requests using a start index and a number of requested contracts
    // function getActiveBorrowRequestViaLimit(
    //     uint256 startIndex,
    //     uint256 requestedNumber
    // ) external view returns (address[] memory borrowRequests) {
    //     address[]
    //         memory borrowRequest = getTotalActiveBorrowRequestContractAddresses();
    //     uint256 counter = 0;
    //     for (uint256 i = 0; i < borrowRequest.length; i++) {
    //         if (i < startIndex) {
    //             continue;
    //         } else if (i >= startIndex) {
    //             borrowRequest[counter] = address(borrowRequest[i]);
    //             if (counter >= requestedNumber) {
    //                 break;
    //             }
    //             counter++;
    //         }
    //     }
    //     address[] memory requestedBorrowRequest = new address[](counter);
    //     for (uint256 i = 0; i < counter; i++) {
    //         requestedBorrowRequest[i] = address(borrowRequest[i]);
    //     }
    //     return requestedBorrowRequest;
    // }

    // // @dev returns the total active borrow requests count.
    // function getTotalActiveBorrowRequestContractCount()
    //     external
    //     view
    //     returns (uint256 count)
    // {
    //     address[]
    //         memory borrowRequests = getTotalActiveBorrowRequestContractAddresses();
    //     return borrowRequests.length;
    // }
}
