// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title LimitMarket
 * @author ButterySwap Protocol
 * @notice
 */

// debug
import {Script, console} from "forge-std/Script.sol";

/*//////////////////////////////////////////////////////////////
                                IMPORTS
    //////////////////////////////////////////////////////////////*/

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IProtocolManager} from "./interfaces/IProtocolManager.sol";
import {IBorrowRequestFactory} from "./interfaces/IBorrowRequestFactory.sol";
import {ILendRequestFactory} from "./interfaces/ILendRequestFactory.sol";

contract LimitMarket is ReentrancyGuard, Ownable {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error UnauthorizedAccess(address caller);
    // new
    error LimitMarket_InvalidTokenCount(uint256 tokenCount);
    error LimitMarket_NoCollateralSent(uint256 collateralAmount);
    error LimitMarket_EnforcerNotInitialized();
    error LimitMarket_NoAmountSent(uint256 balance, uint256 amountSent);
    error LimitMarket_InvalidAmount(uint256 balance, uint256 amountSent);
    error LimitMarket_InsufficientBalance(uint256 balance, uint256 collateral);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    IProtocolManager private immutable protocolManager;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event TokensDeposited(
        address indexed user,
        address[] tokenAddress,
        uint256 amount
    );

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    constructor(address _protocolManager) Ownable(msg.sender) {
        protocolManager = IProtocolManager(_protocolManager);
        // @audit set the address of this contract within protocol manager initialize function
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL BORROW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal function to create a new BorrowRequest instance
    /// @param collateralAmount The amount of collateral to be locked
    /// @param tokens The list of tokens to be used as collateral
    function Borrow(
        uint256[] calldata collateralAmount,
        uint256 loanAmountRequested,
        address[] calldata tokens,
        bool priority
    ) external payable nonReentrant {
        IBorrowRequestFactory(protocolManager.BorrowRequestFactory())
            .createRequest(
                collateralAmount,
                loanAmountRequested,
                tokens,
                msg.sender,
                priority
            );
    }

    function addLiquidityToBorrowRequest(
        address borrowRequest,
        address[] calldata tokens,
        uint256[] calldata collateralAmounts,
        uint256 _loanAmountRequested
    ) external payable nonReentrant {
        IBorrowRequestFactory(protocolManager.BorrowRequestFactory())
            .addLiquidity(
                msg.sender,
                borrowRequest,
                tokens,
                collateralAmounts,
                _loanAmountRequested
            );
    }

    function prioritizeBorrowRequest(
        address borrowRequest
    ) external payable nonReentrant {
        IBorrowRequestFactory(protocolManager.BorrowRequestFactory())
            .prioritizeLoanRequest(msg.sender, borrowRequest);
    }

    function cancelBorrowRequest(
        address borrowRequest
    ) external payable nonReentrant {
        IBorrowRequestFactory(protocolManager.BorrowRequestFactory())
            .cancelRequest(msg.sender, borrowRequest);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL LEND FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function Lend(bool _priority) external payable nonReentrant {
        ILendRequestFactory(protocolManager.LendRequestFactory()).createRequest(
            msg.sender,
            _priority
        );
    }

    function prioritizeLendRequest(
        address lendRequest
    ) external payable nonReentrant {
        ILendRequestFactory(protocolManager.LendRequestFactory())
            .prioritizeLoanRequest(msg.sender, lendRequest);
    }
    function addLiquidityToLendRequest(
        address lendRequest
    ) external payable nonReentrant {
        ILendRequestFactory(protocolManager.LendRequestFactory()).addLiquidity(
            msg.sender,
            lendRequest
        );
    }
    function cancelLendRequest(
        address lendRequest
    ) external payable nonReentrant {
        ILendRequestFactory(protocolManager.LendRequestFactory()).cancelRequest(
            msg.sender,
            lendRequest
        );
    }

    ////////////////////////
    /// Public Functions ///
    ////////////////////////

    ////////////////////////
    /// Internal Functions ///
    ////////////////////////

    ////////////////////////
    /// Private Functions ///
    ////////////////////////

    ////////////////////////////////////////////////
    /// External & Public View & Pure Functions ///
    //////////////////////////////////////////////

    // **** borrow requests functions ****//
    /// move all getters to individual interfaces or limit market interface
    // function getBorrowersPositionOnQue(
    //     address borrowRequest
    // ) external view returns (uint256 position) {
    //     return
    //         BorrowRequestFactory.getBorrowRequestPositionOnActiveRequestQue(
    //             borrowRequest
    //         );
    // }

    // returns specific number of requests using a start index and a number of requested contracts
    // function getActiveBorrowRequestViaLimit(
    //     uint256 _startIndex,
    //     uint256 _numberOfResponse,
    //     uint256 _batchLimit
    // ) external view returns (address[] memory borrowRequests) {
    //     return
    //         BorrowRequestFactory.getBatchedActiveBorrowRequestContractAddresses(
    //             _startIndex,
    //             _numberOfResponse,
    //             _batchLimit
    //         );
    // }

    // @dev returns the total active borrow requests count.
    // function getTotalActiveBorrowRequestContractCount()
    //     external
    //     view
    //     returns (uint256 numberOfContracts)
    // {
    //     return BorrowRequestFactory.getTotalActiveBorrowRequestContractCount();
    // }

    // @dev returns the total active borrow requests prioritized addresses.
    // function getPrioritizedBorrowRequestAddress(
    //     uint256 batchLimit,
    //     uint256 numOfResponse
    // ) external view returns (address[] memory prioritizedLoans) {
    //     return
    //         BorrowRequestFactory.getTotalActivePrioritizedBorrowRequests(
    //             batchLimit,
    //             numOfResponse
    //         );
    // }

    // **** lend requests functions ****//

    // function getLendersPositionOnQue(
    //     address lendRequest
    // ) external view returns (uint256 position) {
    //     return
    //         LendRequestFactory.getLendRequestPositionOnActiveRequestQue(
    //             lendRequest
    //         );
    // }

    // function getPrioritizedLendRequestAddress(
    //     uint256 batchLimit,
    //     uint256 numOfResponse
    // ) external view returns (address[] memory prioritizedLoans) {
    //     return
    //         LendRequestFactory.getTotalActivePrioritizedLendRequests(
    //             batchLimit,
    //             numOfResponse
    //         );
    // }

    // @dev returns the total active lend requests count.
    // function getTotalActiveLendRequestContractCount()
    //     external
    //     view
    //     returns (uint256 count)
    // {
    //     return LendRequestFactory.getTotalActiveLendRequestContractCount();
    // }

    // returns specific number of requests using a start index and a number of requested contracts
    // function getActiveLendRequestViaLimit(
    //     uint256 _startIndex,
    //     uint256 _numberOfResponse,
    //     uint256 _batchLimit
    // ) external view returns (address[] memory lendRequests) {
    //     return
    //         LendRequestFactory.getBatchedActiveLendRequestAddresses(
    //             _startIndex,
    //             _numberOfResponse,
    //             _batchLimit
    //         );
    // }
}
