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

    //////////////////
    /// Functions ///
    ////////////////

    constructor(address supportedTokensAddress) {
        supportedTokensContract = ISupportedTokens(supportedTokensAddress);
    }

    ////////////////////////
    ///External Functions ///
    ////////////////////////

    /// @notice Creates a new BorrowRequest_v1 instance
    /// @param _collateralAmount The amount of collateral to be locked
    /// @param _tokens The list of tokens to be used as collateral
    /// @param _enforcerContract The address of the enforcer contract
    /// @return _BorrowRequest The newly created BorrowRequest_v1 instance
    function createBorrowRequest(
        uint256 _collateralAmount,
        address[] calldata _tokens,
        address _enforcerContract
    ) external returns (address _BorrowRequest) {
        _BorrowRequest = rawCreateBorrowRequest(
            _collateralAmount,
            _tokens,
            _enforcerContract
        );
    }

    /// @notice Internal function to create a new BorrowRequest_v1 instance
    /// @param collateralAmount The amount of collateral to be locked
    /// @param tokens The list of tokens to be used as collateral
    /// @param enforcerContract The address of the enforcer contract
    /// @return borrowRequestAddress The newly created BorrowRequest_v1 instance address
    function rawCreateBorrowRequest(
        uint256 collateralAmount,
        address[] calldata tokens,
        address enforcerContract
    ) internal returns (address borrowRequestAddress) {
        // checks
        if (tokens.length == 0 || tokens.length > 3)
            revert BorrowRequestFactory_InvalidTokenCount(tokens.length);
        if (collateralAmount == 0)
            revert BorrowRequestFactory_NoCollateralSent(collateralAmount);

        for (uint256 index = 0; index < tokens.length; index++) {
            if (!supportedTokensContract.checkTokenIsApproved(tokens[index])) {
                revert BorrowRequestFactory_unSupportedToken(tokens[index]);
            }
            erc20TokenLibrary.increaseAllowance(
                tokens[index],
                address(this),
                collateralAmount
            );
        }

        // effects
        address[2] memory owners = [msg.sender, address(enforcerContract)];
        BorrowRequest_v1 BorrowRequest = new BorrowRequest_v1(
            owners,
            collateralAmount,
            tokens,
            block.timestamp
        );

        totalBorrowRequestArray.push(BorrowRequest);
        userToBorrowRequestAddress[msg.sender].push(address(BorrowRequest));

        // interactions
        for (uint256 index = 0; index < tokens.length; index++) {
            erc20TokenLibrary.transferFromTokens(
                tokens[index],
                msg.sender,
                address(BorrowRequest),
                collateralAmount
            );
        }
        borrowRequestAddress = address(BorrowRequest);
        return borrowRequestAddress;
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

    // returns specific number of requests using a start index and a number of requested contracts
    function getActiveBorrowRequestViaLimit(
        uint256 startIndex,
        uint256 requestedNumber
    ) external view returns (address[] memory borrowRequests) {
        address[]
            memory borrowRequest = getTotalActiveBorrowRequestContractAddresses();
        uint256 counter = 0;
        for (uint256 i = 0; i < borrowRequest.length; i++) {
            if (i < startIndex) {
                continue;
            } else if (i >= startIndex) {
                borrowRequest[counter] = address(borrowRequest[i]);
                if (counter >= requestedNumber) {
                    break;
                }
                counter++;
            }
        }
        address[] memory requestedBorrowRequest = new address[](counter);
        for (uint256 i = 0; i < counter; i++) {
            requestedBorrowRequest[i] = address(borrowRequest[i]);
        }
        return requestedBorrowRequest;
    }

    // @dev returns the total active borrow requests count.
    function getTotalActiveBorrowRequestContractCount()
        external
        view
        returns (uint256 count)
    {
        address[]
            memory borrowRequests = getTotalActiveBorrowRequestContractAddresses();
        return borrowRequests.length;
    }
}
