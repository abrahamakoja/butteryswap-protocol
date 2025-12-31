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
        address borrower;
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

    struct Node {
        uint256 prev;
        uint256 next;
    }

    struct Queue {
        uint256 head;
        uint256 tail;
        mapping(uint256 => Node) nodes;
    }

    /*//////////////////////////////////////////////////////////////
                           ENUMS
    //////////////////////////////////////////////////////////////*/
    enum RequestState {
        CLOSED,
        OPEN,
        CANCELLED,
        SETTLED,
        UPDATING
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
    uint256 dough;
    uint256 bread;

    Queue internal priorityQueue;
    Queue internal normalQueue;

    mapping(uint256 ID => BorrowRequestDetails borrowRequestDetails)
        internal _borrowRequestDetails;

    mapping(address borrower => uint256[] borrowRequestsID)
        internal borrowerToRequestsID;

    mapping(uint256 requestID => uint256 requestQueuePosition)
        internal requestQueuePosition; // @audit get position

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event BorrowRequestCreated(
        uint256 indexed requestID,
        uint256 indexed amountToBorrow
    );
    event BreadMinted(address indexed borrower, uint256 indexed breadMinted);
    event collateralAmountIncreased(
        uint256 indexed requestID,
        uint256 indexed collateralValue,
        uint256 indexed amountToBorrow
    );
    event BorrowRequestPrioritized(uint256 indexed requestID);

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
        dough = 1;
        bread = 2;

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
        nonReentrant
        returns (uint256 requestID)
    {
        uint256 collateralValue;
        requestID = nextID++;

        BorrowRequestDetails
            storage borrowRequestDetails = _borrowRequestDetails[requestID];

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
            : amountToBorrow; //@audit token amounts must be formatted corrrectly in 18 decimals
        borrowRequestDetails.borrower = borrower;
        borrowRequestDetails.amountToBorrow = eligibleAmountToBorrow;
        borrowRequestDetails.priority = priority;
        borrowRequestDetails.timeCreated = block.timestamp;
        borrowRequestDetails.interestRate = 1e18; // @audit fix
        borrowRequestDetails.dueDate = block.timestamp + 7 days; // @audit fix
        borrowRequestDetails.BreadBalance = eligibleAmountToBorrow;
        borrowRequestDetails.requestID = requestID;
        borrowRequestDetails.state = RequestState.OPEN;
        borrowerToRequestsID[borrower].push(requestID);

        if (priority == true) {
            _enQueue(priorityQueue, requestID);
            emit BorrowRequestPrioritized(requestID);
        } else {
            _enQueue(normalQueue, requestID);
        }

        // @audit check ltv before proceeding
        // @audit collect fee

        /// EVENTS
        emit BorrowRequestCreated(requestID, amountToBorrow);
        emit BreadMinted(borrower, eligibleAmountToBorrow);
        // mint
        if (
            address(Backery) == address(0) ||
            address(ProtocolManager.Backery()) != address(Backery)
        ) {
            Backery = IBackery(address(ProtocolManager.Backery()));
            require(address(Backery) != address(0), "Backery not set");
        }

        Backery.mint(borrower, bread, eligibleAmountToBorrow * 1 ether); //@audit overflow?
    }

    function prioritizeBorrowRequest(
        address borrower,
        uint256 requestID
    ) external payable onlyRole(LIMIT_MARKET) nonReentrant {
        // checks
        BorrowRequestDetails
            storage borrowRequestDetails = _borrowRequestDetails[requestID];
        // check borrower isowner
        require(borrowRequestDetails.borrower == borrower, "not owner");

        // check state
        require(
            borrowRequestDetails.state == RequestState.OPEN,
            "loan state invalid"
        );
        //  checks position hasnt been skipped if yes re-assign next
        // change state
        borrowRequestDetails.state = RequestState.UPDATING;

        borrowRequestDetails.priority = true;

        _enQueue(priorityQueue, requestID);
        // EVENTS
        emit BorrowRequestPrioritized(requestID);
        // @audit understand dequeeue first
        borrowRequestDetails.state == RequestState.OPEN;
    }

    function increaseCollaterallAmount(
        address borrower,
        uint256 requestID,
        address[] calldata tokens,
        uint256[] calldata collateralAmounts,
        uint256 amountToBorrow
    ) external payable onlyRole(LIMIT_MARKET) nonReentrant {
        // @audit add zero checks and overflows
        uint256 collateralValue;
        uint256 currentTokenCount;
        uint256 newTokenCount;
        // uint256 eligibleAmountToBorrow;
        BorrowRequestDetails
            storage borrowRequestDetails = _borrowRequestDetails[requestID];
        currentTokenCount = borrowRequestDetails.tokenDetails.length;
        TokenDetails memory tokendetails; //@audit
        // check borrower isowner
        require(borrowRequestDetails.borrower == borrower, "not owner");

        // check state
        require(
            borrowRequestDetails.state == RequestState.OPEN,
            "loan state invalid"
        );
        // change state
        borrowRequestDetails.state = RequestState.UPDATING;

        // check if new deposit exceeds eligible borrow limit @audit do this once we start tracking reserves
        // ensure both tokens and collateralmatches
        require(tokens.length == collateralAmounts.length, "range mismatch");
        // ensure tokens are supported
        for (uint256 i = 0; i < tokens.length; i++) {
            // checks
            require(collateralAmounts[0] != 0, "invalid amount");
            collateralValue += TokenManager.getTotalTokenEthValue(
                tokens[i],
                collateralAmounts[i]
            );

            if (tokens[i] == tokendetails.token) {
                tokendetails.amountDeposited += collateralAmounts[i];
                tokendetails.tokenValue += collateralValue;
            } else {
                tokendetails.token = tokens[i];
                tokendetails.amountDeposited = collateralAmounts[i];
                tokendetails.tokenValue = collateralValue;
                newTokenCount++;
            }

            borrowRequestDetails.tokenDetails.push(tokendetails);

            /// @dev transfer tokens to loanManager contract
            erc20TokenLibrary.transferFromTokens(
                tokens[i],
                address(borrower),
                address(this),
                collateralAmounts[i]
            ); // @audit change to token library
        }

        uint256 eligibleAmountToBorrow = collateralValue <= amountToBorrow
            ? collateralValue
            : amountToBorrow; //@audit token amounts must be formatted corrrectly in 18 decimals

        // check if tokens already supplied exceed limit
        require(
            (currentTokenCount + newTokenCount) <=
                ProtocolManager.MAX_ASSET_LIMIT(),
            "token limit exceeded"
        );

        //  checks position hasnt been skipped if yes re-assign next
        // @audit fully implement this during enforcer

        // effects
        /// EVENTS
        emit collateralAmountIncreased(
            requestID,
            collateralValue,
            amountToBorrow
        );
        emit BreadMinted(borrower, eligibleAmountToBorrow);
        // @audit collect fee
        // mints additional bread
        Backery.mint(borrower, bread, eligibleAmountToBorrow * 1 ether); //@audit overflow?

        borrowRequestDetails.state == RequestState.OPEN;
    }

    function cancelBorrowRequest(
        address borrower,
        uint256 requestID
    ) external payable onlyRole(LIMIT_MARKET) nonReentrant {
        BorrowRequestDetails
            storage borrowRequestDetails = _borrowRequestDetails[requestID];

        // TokenDetails memory tokendetails; //@audit
        // // check borrower isowner
        require(borrowRequestDetails.borrower == borrower, "not owner");

        // // check state
        require(
            borrowRequestDetails.state == RequestState.OPEN,
            "loan state invalid"
        );
        // // change state
        borrowRequestDetails.state = RequestState.UPDATING;
        // reset request values
        uint256 BreadBalance = borrowRequestDetails.BreadBalance;

        borrowRequestDetails.dueDate = 0; // @audit fix
        borrowRequestDetails.BreadBalance = 0;
        borrowRequestDetails.state = RequestState.CANCELLED;

        // remove from queue
        if (borrowRequestDetails.priority == true) {
            _removeFromQueue(priorityQueue, requestID);
        } else {
            _removeFromQueue(normalQueue, requestID);
        }
        // collect cancelation fee @audit do this when fee contract is ready
        // burn bread
        Backery.burn(borrower, bread, BreadBalance);
        // transfer tokens back to borrower

        console2.log("boorower", borrowRequestDetails.borrower);
        console2.log("bread balance", borrowRequestDetails.BreadBalance);
        console2.log("state", uint8(borrowRequestDetails.state));
        console2.log("due date", borrowRequestDetails.dueDate);
    }

    /*//////////////////////////////////////////////////////////////
                 PUBLIC, PRIVATE AND INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function isRequestPrioritized(
        uint256 requestID
    ) public view returns (bool) {
        BorrowRequestDetails memory details = _borrowRequestDetails[requestID];
        return details.priority;
    }

    function _enQueue(Queue storage q, uint256 ID) private {
        if (q.tail != 0) {
            q.nodes[q.tail].next = ID;
            q.nodes[ID].prev = q.tail;
        } else {
            q.head = ID;
        }
        q.tail = ID;
    }

    function _removeFromQueue(Queue storage q, uint256 ID) private {
        Node storage n = q.nodes[ID];

        uint256 prev = n.prev;
        uint next = n.next;

        if (prev != 0) {
            q.nodes[prev].next = next;
        } else {
            q.head = next;
        }

        if (next != 0) {
            q.nodes[next].prev = prev;
        } else {
            q.tail = prev;
        }

        delete q.nodes[ID];
    }

    function _deQueue(Queue storage q) private returns (uint256 ID) {
        ID = q.head;
        require(ID != 0, "empty Queue");

        uint next = q.nodes[ID].next;

        q.head = next;

        if (next != 0) {
            q.nodes[next].prev = 0;
        } else {
            q.tail = 0;
        }

        delete q.nodes[ID];
    }

    /*//////////////////////////////////////////////////////////////
                              PUBLIC PURE/VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getBorrowerRequestsDetails(
        address borrower
    ) public view returns (uint256[] memory requestsID) {
        uint256 count = borrowerToRequestsID[borrower].length;
        requestsID = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            requestsID[i] = borrowerToRequestsID[borrower][i];
        }
        return requestsID;
    }

    function getBorrowRequestDetails(
        uint256 _requestID
    )
        public
        view
        returns (
            address borrower,
            uint256 amountToBorrow,
            bool priority,
            uint256 timeCreated,
            uint256 interestRate,
            uint256 dueDate,
            uint256 BreadBalance,
            uint256 requestID,
            address[] memory tokens,
            uint256[] memory amountDeposited,
            uint256[] memory tokenvalue,
            uint8 state
        )
    {
        BorrowRequestDetails memory details = _borrowRequestDetails[_requestID];
        uint256 count = details.tokenDetails.length;

        tokens = new address[](count);
        amountDeposited = new uint256[](count);
        tokenvalue = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            tokens[i] = details.tokenDetails[i].token;
            amountDeposited[i] = details.tokenDetails[i].amountDeposited;
            tokenvalue[i] = details.tokenDetails[i].tokenValue;
        }

        return (
            details.borrower,
            details.amountToBorrow,
            details.priority,
            details.timeCreated,
            details.interestRate,
            details.dueDate,
            details.BreadBalance,
            details.requestID,
            tokens,
            amountDeposited,
            tokenvalue,
            uint8(details.state)
        );
    }

    /*//////////////////////////////////////////////////////////////
                              PRIVATE VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // gap
    uint256[60] private __gap;
}
