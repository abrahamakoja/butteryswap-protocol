// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title LoanManager
/// @author ButterySwap Protocol
/// @notice  @audit Explain to an end user what this does
/// @dev @audit Explain to a developer any extra details

//  debug @audit
import {Script, console2} from "forge-std/Script.sol";

/*//////////////////////////////////////////////////////////////
                                 IMPORT
//////////////////////////////////////////////////////////////*/

import {erc20TokenLibrary} from "./libraries/erc20TokenLibrary.sol";
import {IProtocolManager} from "./interfaces/IProtocolManager.sol";
import {ITokenManager} from "./interfaces/ITokenManager.sol";
import {IBackery} from "./interfaces/IBackery.sol";
import {LoanConfigLibrary} from "./libraries/LoanConfigLibrary.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

// new

/**
 * 
 * 
 * ███████████              █████     █████                                   █████████                                     
*▒▒███▒▒▒▒▒███            ▒▒███     ▒▒███                                   ███▒▒▒▒▒███                                    
* ▒███    ▒███ █████ ████ ███████   ███████    ██████  ████████  █████ ████▒███    ▒▒▒  █████ ███ █████  ██████   ████████ 
* ▒██████████ ▒▒███ ▒███ ▒▒▒███▒   ▒▒▒███▒    ███▒▒███▒▒███▒▒███▒▒███ ▒███ ▒▒█████████ ▒▒███ ▒███▒▒███  ▒▒▒▒▒███ ▒▒███▒▒███
* ▒███▒▒▒▒▒███ ▒███ ▒███   ▒███      ▒███    ▒███████  ▒███ ▒▒▒  ▒███ ▒███  ▒▒▒▒▒▒▒▒███ ▒███ ▒███ ▒███   ███████  ▒███ ▒███
* ▒███    ▒███ ▒███ ▒███   ▒███ ███  ▒███ ███▒███▒▒▒   ▒███      ▒███ ▒███  ███    ▒███ ▒▒███████████   ███▒▒███  ▒███ ▒███
* ███████████  ▒▒████████  ▒▒█████   ▒▒█████ ▒▒██████  █████     ▒▒███████ ▒▒█████████   ▒▒████▒████   ▒▒████████ ▒███████ 
▒▒▒▒▒▒▒▒▒▒▒    ▒▒▒▒▒▒▒▒    ▒▒▒▒▒     ▒▒▒▒▒   ▒▒▒▒▒▒  ▒▒▒▒▒       ▒▒▒▒▒███  ▒▒▒▒▒▒▒▒▒     ▒▒▒▒ ▒▒▒▒     ▒▒▒▒▒▒▒▒  ▒███▒▒▒                                                                   ███ ▒███                                        ▒███     
                                                                ▒▒██████                                         █████    
                                                                 ▒▒▒▒▒▒                                         ▒▒▒▒▒   

 ███████████                      █████                               ████ 
▒▒███▒▒▒▒▒███                    ▒▒███                               ▒▒███ 
 ▒███    ▒███ ████████   ██████  ███████    ██████   ██████   ██████  ▒███ 
 ▒██████████ ▒▒███▒▒███ ███▒▒███▒▒▒███▒    ███▒▒███ ███▒▒███ ███▒▒███ ▒███ 
 ▒███▒▒▒▒▒▒   ▒███ ▒▒▒ ▒███ ▒███  ▒███    ▒███ ▒███▒███ ▒▒▒ ▒███ ▒███ ▒███ 
 ▒███         ▒███     ▒███ ▒███  ▒███ ███▒███ ▒███▒███  ███▒███ ▒███ ▒███ 
 █████        █████    ▒▒██████   ▒▒█████ ▒▒██████ ▒▒██████ ▒▒██████  █████
▒▒▒▒▒        ▒▒▒▒▒      ▒▒▒▒▒▒     ▒▒▒▒▒   ▒▒▒▒▒▒   ▒▒▒▒▒▒   ▒▒▒▒▒▒  ▒▒▒▒▒ 
                                                                           
*
*
*                                                                          
 */

contract LoanManager is
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardTransient
{
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error LoanManager__InvalidAddress();

    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    struct BorrowRequestDetails {
        uint256 amountToBorrow;
        bool priority;
        uint256 timeCreated;
        uint256 interestRate;
        uint256 dueDate;
        uint256 BreadBalance;
        uint256 requestID;
        TokenDetails[] tokenDetails;
        RequestState state;
    }

    struct TokenDetails {
        address token;
        uint256 amountDeposited;
        uint256 tokenValue;
    }

    struct Queue {
        uint256 head;
        uint256 tail;
        mapping(uint256 => uint256) next;
    }

    /*//////////////////////////////////////////////////////////////
                           ENUMS
    //////////////////////////////////////////////////////////////*/
    enum RequestState {
        CLOSED,
        OPEN,
        CANCELLED,
        SETTLED,
        ADDING_LIQUIDITY,
        PRIORITIZING,
        CANCELLING
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public LIMIT_MARKET;

    address public admin;

    IProtocolManager ProtocolManager;

    ITokenManager TokenManager;

    IBackery Backery;

    uint256 nextID;

    Queue private priorityQueue;
    Queue private normalQueue;

    mapping(uint256 ID => BorrowRequestDetails borrowRequestDetails)
        private _borrowRequestDetails;

    mapping(address borrower => uint256[] borrowRequestsID)
        private borrowerToRequestsID;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    modifier addressIsValid(address _address) {
        require((_address != address(0)), LoanManager__InvalidAddress());
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function initialize(address protocolManager) public initializer {
        // @audit lock after initialize
        __AccessControl_init();
        LIMIT_MARKET = keccak256("LIMIT_MARKET");
        ProtocolManager = IProtocolManager(protocolManager);
        TokenManager = ITokenManager(ProtocolManager.TokenManager());
        Backery = IBackery(address(0));

        admin = ProtocolManager.deployer();
        nextID = 0;

        bool adminRoleGranted = _grantRole(DEFAULT_ADMIN_ROLE, admin);

        bool limitMarketContractRoleGranted = _grantRole(
            LIMIT_MARKET,
            ProtocolManager.LIMIT_MARKET_CONTRACT_ADDRESS()
        );
        require(adminRoleGranted && limitMarketContractRoleGranted);

        ProtocolManager.setloanManager(address(this), msg.sender);
    }

    function _authorizeUpgrade(
        address
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createBorrowRequest(
        address[] calldata tokens,
        uint256[] calldata collateralAmount,
        uint256 amountToBorrow,
        address borrower,
        bool priority
    )
        external
        payable
        onlyRole(LIMIT_MARKET)
        returns (uint256 borrowRequestID)
    {
        uint256 collateralValue;
        borrowRequestID = nextID++;

        BorrowRequestDetails
            storage borrowRequestDetails = _borrowRequestDetails[
                borrowRequestID
            ];

        for (uint256 i = 0; i < tokens.length; i++) {
            TokenDetails memory tokendetails;
            uint256 tokenValue = TokenManager.getTotalTokenEthValue(
                tokens[i],
                collateralAmount[i]
            );

            collateralValue += tokenValue;
            tokendetails.token = tokens[i];
            tokendetails.amountDeposited = collateralAmount[i];
            tokendetails.tokenValue = tokenValue;

            borrowRequestDetails.tokenDetails.push(tokendetails);

            /// @dev transfer tokens to loanManager contract
            erc20TokenLibrary.transferFromTokens(
                tokens[i],
                address(borrower),
                address(this),
                collateralAmount[i]
            ); // @audit change to token library
        }

        uint256 eligibleAmountToBorrow = collateralValue <= amountToBorrow
            ? collateralValue
            : amountToBorrow;
        borrowRequestDetails.amountToBorrow = eligibleAmountToBorrow;
        borrowRequestDetails.priority = priority;
        borrowRequestDetails.timeCreated = block.timestamp;
        borrowRequestDetails.interestRate = 1e18; // @audit fix
        borrowRequestDetails.dueDate = block.timestamp + 7 days; // @audit fix
        borrowRequestDetails.BreadBalance = eligibleAmountToBorrow;
        borrowRequestDetails.requestID = borrowRequestID;
        borrowRequestDetails.state = RequestState.OPEN;
        borrowerToRequestsID[borrower].push(borrowRequestID);

        if (priority == true) {
            _enQueue(priorityQueue, borrowRequestID);
        } else {
            _enQueue(normalQueue, borrowRequestID);
        }

        // @audit check ltv before proceeding

        // mint
        if (
            address(Backery) == address(0) ||
            address(ProtocolManager.Backery()) != address(Backery)
        ) {
            Backery = IBackery(address(ProtocolManager.Backery()));
            require(address(Backery) != address(0), "Backery not set");
        }

        Backery.mint(borrower, 2, eligibleAmountToBorrow * 1 ether); //@audit overflow?
    }

    /*//////////////////////////////////////////////////////////////
                 PUBLIC, PRIVATE AND INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _enQueue(Queue storage q, uint256 ID) private {
        if (q.tail != 0) {
            q.next[q.tail] = ID;
        } else {
            q.head = ID;
        }
        q.tail = ID;
    }

    function _deQueue(Queue storage q) private returns (uint256 ID) {
        ID = q.head;
        require(ID != 0, "empty Queue");
        q.head = q.next[ID];
        delete q.next[ID];

        if (q.head == 0) {
            q.tail = 0;
        }
    }

    /*//////////////////////////////////////////////////////////////
                              PRIVATE VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // gap
    uint256[60] private __gap;
}
