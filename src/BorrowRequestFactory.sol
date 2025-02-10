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
    error BorrowRequestFactory_InvalidTokenCount(uint256 tokenCount);
    error BorrowRequestFactory_NoCollateralSent(uint256 collateralAmount);
    error inValidContractAddress();

    /////////////////////////
    /// Type Declarations ///
    ///////////////////////

    using erc20TokenLibrary for erc20TokenLibrary.tokenData;

    /////////////////////////
    /// State variables ///
    ///////////////////////

    BorrowRequest_v1[] public totalBorrowRequests;
    BorrowRequest_v1[] private s_prioritizedBorrowRequests;
    ISupportedTokens private immutable supportedTokensContract;
    mapping(address => address[]) private userToBorrowRequestAddresses;
    mapping(address => address[])
        private userToPrioritizedBorrowRequestAddresses;
    mapping(address loanRequest => bool prioritized)
        private s_loanIsPrioritized;
    mapping(address => bool) private s_isValidContract;
    uint256 private immutable i_originationFee;
    uint256 private constant MAX_ASSET_LIMIT = 3;
    uint256 private constant MAX_OWNERS_LIMIT = 2;

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

    /// @notice Creates a new BorrowRequest instance
    /// @param _collateralAmount The amount of collateral to be locked
    /// @param _tokens The list of tokens to be used as collateral
    /// @param _owners The address of the enforcer contract
    /// @param _priority The address of the enforcer contract
    function createBorrowRequest(
        uint256 _collateralAmount,
        uint256 _loanAmountRequested,
        address[MAX_ASSET_LIMIT] calldata _tokens,
        address[MAX_OWNERS_LIMIT] calldata _owners,
        bool _priority
    ) external {
        _rawCreateBorrowRequest(_collateralAmount,_loanAmountRequested, _tokens, _owners, _priority);
    }

    ////////////////////////////////////////////////  
    /// External & Public View & Pure Functions ///
    //////////////////////////////////////////////

    // Function to retrieve all borrow request contracts for a user // legacy
    function getUserToBorrowRequestAddresses(
        address user
    )
        external
        view
        returns (
            address[] memory borrowRequestAddresses,
            address[] memory prioritizedBorrowRequestAddresses
        )
    {
        return (
            userToBorrowRequestAddresses[user],
            userToPrioritizedBorrowRequestAddresses[user]
        );
    }

    function getTotalActivePrioritizedBorrowRequests(
        uint256 _batchLimit,
        uint256 numOfResponse
    ) external view returns (address[] memory) {
        uint256 total = s_prioritizedBorrowRequests.length;
        uint256 limit = total > _batchLimit ? _batchLimit : total;
        address[] memory borrowRequest = new address[](
            s_prioritizedBorrowRequests.length
        );
        uint256 counter = 0;

        for (uint256 i = 0; i < limit; i++) {
            BorrowRequest_v1 borrowRequest_v1 = BorrowRequest_v1(
                payable(address(s_prioritizedBorrowRequests[i]))
            );
            uint8 status = uint8(borrowRequest_v1.getRequestState());
            if (status != 0) {
                continue;
            }
            borrowRequest[counter] = address(s_prioritizedBorrowRequests[i]);
            if (borrowRequest.length == numOfResponse) {
                break;
            }
            counter++;
        }

        //  console.log(numOfResponse);
        //  console.log(total);
        //   console.log(limit);
        //   console.log(_batchLimit);
        //   console.log(address(borrowRequest[0]));
        //   console.log(borrowRequest.length );
        //   console.log(s_prioritizedBorrowRequests.length);
        //   console.log(  payable(address(s_prioritizedBorrowRequests[0])));

        address[] memory activePrioritizedBorrowRequests = new address[](
            counter
        );
        for (uint256 i = 0; i < counter; i++) {
            activePrioritizedBorrowRequests[i] = borrowRequest[i];
            // console.log(address(activeBorrowRequest[i]));
        }
        return activePrioritizedBorrowRequests;
    }

    function getBatchedActiveBorrowRequestContractAddresses(
        uint256 startIndex,
        uint256 numberOfResponse,
        uint256 _batchLimit
    ) external view returns (address[] memory) {
        uint256 total = _getTotalActiveBorrowRequestContractAddresses().length;
        uint256 _startIndex = startIndex > total ? 0 : startIndex;
        uint256 limit = total > _batchLimit ? _batchLimit : total;
        uint256 _numberOfResponse = numberOfResponse > limit
            ? limit
            : numberOfResponse;
        address[]
            memory activeBorrowRequests = _getTotalActiveBorrowRequestContractAddresses();
        address[] memory batchedBorrowRequests = new address[](
            _numberOfResponse
        );

        // console.log(total);
        // console.log(limit);

        for (uint256 i = _startIndex; i < _numberOfResponse; i++) {
            if (i < startIndex) {
                continue;
            }
            batchedBorrowRequests[i] = activeBorrowRequests[i];
            //    console.log(address(batchedBorrowRequests[i]));

            if (i > limit) {
                break;
            }
        }
        return batchedBorrowRequests;
    }

    function getTotalActiveBorrowRequestContractCount()
        external
        view
        returns (uint256 numberOfContracts)
    {
        // console.log(_getTotalActiveBorrowRequestContractAddresses().length);
        return _getTotalActiveBorrowRequestContractAddresses().length;
    }

    // @dev returns the total active borrow requests addresses.
    function _getTotalActiveBorrowRequestContractAddresses()
        private
        view
        returns (address[] memory)
    {
        address[] memory borrowRequest = new address[](
            totalBorrowRequests.length
        );
        uint256 counter = 0;

        for (uint256 i = 0; i < totalBorrowRequests.length; i++) {
            BorrowRequest_v1 borrowRequest_v1 = BorrowRequest_v1(
                payable(address(totalBorrowRequests[i]))
            );
            uint8 status = uint8(borrowRequest_v1.getRequestState());
            if (status != 0) {
                continue;
            }
            borrowRequest[counter] = address(totalBorrowRequests[i]);
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
        address _borrowRequest
    ) external view returns (uint256 position) {
        if (s_isValidContract[_borrowRequest] == false)
            revert inValidContractAddress();
        address[]
            memory borrowRequests = _getTotalActiveBorrowRequestContractAddresses();
        for (uint256 i = 0; i < borrowRequests.length; i++) {
            if (borrowRequests[i] == address(_borrowRequest)) {
                position = i + 1;
            }
        }
        return position;
    }

    ////////////////////////
    /// Internal Functions ///
    ////////////////////////

    ////////////////////////
    /// Private Functions ///
    ////////////////////////

    /// @notice Internal function to create a new BorrowRequest_v1 instance
    /// @param collateralAmount The amount of collateral to be locked
    /// @param tokens The list of tokens to be used as collateral
    /// @param owners The address of the enforcer contract
    /// @param priority The address of the enforcer contract
    function _rawCreateBorrowRequest(
        uint256 collateralAmount,
        uint256 loanAmountRequested,
        address[MAX_ASSET_LIMIT] calldata tokens,
        address[MAX_OWNERS_LIMIT] calldata owners,
        bool priority
    ) private {
        // uint256 tokenCount;
        // checks
        // check loanAmountRequested
        if (tokens.length == 0 || tokens.length > MAX_ASSET_LIMIT)
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
            // tokenCount++;
        }

        // effects
        BorrowRequest_v1 BorrowRequest = new BorrowRequest_v1(
            owners,
            collateralAmount,
            loanAmountRequested,
            tokens,
            block.timestamp,
            i_originationFee,
            MAX_ASSET_LIMIT,
            address(supportedTokensContract)
        );

        // check and update priority
        if (priority) {
            s_loanIsPrioritized[address(BorrowRequest)] = true;
            s_prioritizedBorrowRequests.push(BorrowRequest);
            userToPrioritizedBorrowRequestAddresses[msg.sender].push(
                address(BorrowRequest)
            );
        } else {
            totalBorrowRequests.push(BorrowRequest);
            userToBorrowRequestAddresses[msg.sender].push(
                address(BorrowRequest)
            );
        }
        // priority should have its own handler
        // integrate into enforcer

        s_isValidContract[address(BorrowRequest)] = true;

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

    function getPrioritizedBorrowRequest(
        address BorrowRequestContractAddress
    ) external view returns (bool isPrioritized) {
        return s_loanIsPrioritized[BorrowRequestContractAddress];
    }
}
