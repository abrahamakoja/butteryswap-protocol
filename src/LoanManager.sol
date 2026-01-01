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
    struct LendRequestDetails {
        address lender;
        uint256 amountToLend;
        uint256 timeCreated;
        uint256 DoughBalance;
        uint256 requestID;
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

    IProtocolManager internal ProtocolManager;

    ITokenManager internal TokenManager;

    IBackery internal Backery;

    uint256 internal nextBorrowerID;
    uint256 internal nextLenderID;
    uint256 internal dough;
    uint256 internal bread;
    uint256 internal borrowRequestCount;
    uint256 internal lendRequestCount;

    Queue internal priorityQueue;
    Queue internal normalQueue;

    mapping(uint256 ID => BorrowRequestDetails borrowRequestDetails)
        internal _borrowRequestDetails;

    mapping(address borrower => uint256[] borrowRequestsID)
        internal borrowerToRequestsID;

    mapping(uint256 ID => LendRequestDetails lendRequestDetails)
        internal _lendRequestDetails;

    mapping(address lender => uint256[] lendRequestID)
        internal lenderToRequestsID;

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
    event LendRequestCreated(
        uint256 indexed requestID,
        uint256 indexed amountToLend
    );
    event DoughMinted(address indexed lender, uint256 indexed doughMinted);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier backeryIsSet() {
        if (
            address(Backery) == address(0) ||
            address(ProtocolManager.Backery()) != address(Backery)
        ) {
            Backery = IBackery(address(ProtocolManager.Backery()));
            require(address(Backery) != address(0), "Backery not set");
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    receive() external payable {
        if (msg.sender == address(this)) {
            console2.log("money recieved", msg.value);
        } else {
            console2.log("money burnt");
            revert("not allowed");
        }
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
        nextBorrowerID = 1;
        nextLenderID = 1;
        dough = 1;
        bread = 2;
        borrowRequestCount = 0;
        lendRequestCount = 0;

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

    /*//////////////////////////////////////////////////////////////
                            BORROW FUNCTIONS
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
        backeryIsSet
        onlyRole(LIMIT_MARKET)
        nonReentrant
        returns (uint256 requestID)
    {
        uint256 collateralValue;
        requestID = nextBorrowerID;
        console2.log("function ID", nextBorrowerID);
        console2.log("function requestID", requestID);

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

        // _borrowRequestDetails[requestID] = borrowRequestDetails; // @audit check if this is relevant
        borrowRequestCount++;
        nextBorrowerID++;

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

        Backery.mint(borrower, bread, eligibleAmountToBorrow * 1 ether); //@audit overflow?

        return requestID;
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
        // TokenDetails memory tokendetails; //@audit
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

            if (tokens[i] == borrowRequestDetails.tokenDetails[i].token) {
                borrowRequestDetails
                    .tokenDetails[i]
                    .amountDeposited += collateralAmounts[i];
                borrowRequestDetails
                    .tokenDetails[i]
                    .tokenValue += collateralValue;
            } else {
                borrowRequestDetails.tokenDetails[i].token = tokens[i];
                borrowRequestDetails
                    .tokenDetails[i]
                    .amountDeposited = collateralAmounts[i];
                borrowRequestDetails
                    .tokenDetails[i]
                    .tokenValue = collateralValue;
                newTokenCount++;
            }

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
        uint256 count = borrowRequestDetails.tokenDetails.length;
        address[] memory tokens = new address[](count);
        uint256[] memory amountDeposited = new uint256[](count);
        uint256[] memory tokenValue = new uint256[](count);

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
        borrowRequestCount--;

        // remove from queue
        if (borrowRequestDetails.priority == true) {
            _removeFromQueue(priorityQueue, requestID);
        } else {
            _removeFromQueue(normalQueue, requestID);
        }
        // collect cancelation fee @audit do this when fee contract is ready
        // transfer tokens back to borrower

        (tokens, amountDeposited, tokenValue) = _getTokenAllocations(
            count,
            borrowRequestDetails
        );

        //  @audit emit events

        uint256 _tokenValue;

        /** BORROWER WITHDRAWS ALL COLLATERAL */
        for (uint256 i = 0; i < tokens.length; i++) {
            erc20TokenLibrary.transfer(
                address(tokens[i]),
                address(borrower),
                amountDeposited[i]
            );
            _tokenValue += tokenValue[i];
        }

        require(BreadBalance == _tokenValue, "balance mismatch");

        // burn bread
        Backery.burn(borrower, bread, BreadBalance);

        console2.log("boorower", borrowRequestDetails.borrower);
        console2.log("bread balance", borrowRequestDetails.BreadBalance);
        console2.log("state", uint8(borrowRequestDetails.state));
        console2.log("due date", borrowRequestDetails.dueDate);
    }

    /*//////////////////////////////////////////////////////////////
                             LEND FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createLendRequest(
        address lender
    )
        external
        payable
        backeryIsSet
        onlyRole(LIMIT_MARKET)
        nonReentrant
        returns (uint256 requestID)
    {
        requestID = nextLenderID;
        console2.log("contract before", address(this).balance);
        // collect fee
        uint256 originationFee = ProtocolManager.calculate_OriginationFee(
            msg.value
        );
        uint256 amountToLend = msg.value - originationFee;
        // update mapping
        LendRequestDetails storage lendRequestDetails = _lendRequestDetails[
            requestID
        ];
        lendRequestDetails.lender = lender;
        lendRequestDetails.amountToLend = amountToLend;
        lendRequestDetails.timeCreated = block.timestamp;
        lendRequestDetails.DoughBalance = amountToLend;
        lendRequestDetails.requestID = requestID;
        lendRequestDetails.state = RequestState.OPEN;
        lendRequestCount++;

        // _lendRequestDetails[requestID] = lendRequestDetails;
        lenderToRequestsID[lender].push(requestID);
        // update lend count
        nextLenderID++;

        // emit event
        emit LendRequestCreated(requestID, amountToLend);
        emit DoughMinted(lender, amountToLend);

        // transfer eth to this address
        console2.log("lend time", lendRequestDetails.timeCreated);
        console2.log("lend amount", lendRequestDetails.amountToLend);

        console2.log(
            "fee contract balance before",
            address(ProtocolManager.FEE_CONTRACT()).balance
        );
        (bool originationFeePaid, ) = ProtocolManager.FEE_CONTRACT().call{
            value: originationFee
        }("");
        (bool success, ) = address(this).call{value: amountToLend}("");
        require(originationFeePaid && success);
        console2.log("contract balance after", address(this).balance);
        console2.log(
            "fee contract balance after",
            address(ProtocolManager.FEE_CONTRACT()).balance
        );

        // mint dough to lender
        Backery.mint(lender, dough, amountToLend);
    }

    function cancelLendRequest(
        address lender,
        uint256 requestID
    ) external payable onlyRole(LIMIT_MARKET) nonReentrant {
        LendRequestDetails storage lendRequestDetails = _lendRequestDetails[
            requestID
        ];

        require(lendRequestDetails.lender == lender, "not owner");
        require(
            lendRequestDetails.state == RequestState.OPEN,
            "loan state invalid"
        );
        lendRequestDetails.state = RequestState.UPDATING;

        uint256 DoughBalance = lendRequestDetails.DoughBalance;

        lendRequestDetails.DoughBalance = 0;
        lendRequestDetails.state = RequestState.CANCELLED;
        lendRequestCount--;
        /** EFFECTS */
        uint256 amountToLend = lendRequestDetails.amountToLend;
        uint256 cancellationFee = 1;
        uint256 amountMinusFee = msg.value - cancellationFee;

        // remove from queue
        require(DoughBalance == amountToLend, "balance mismatch");

        //  @audit emit events

        // burn bread
        Backery.burn(lender, dough, DoughBalance);

        // /** COLLECT CANCELLATION FEE */
        (bool feePaid, ) = ProtocolManager.FEE_CONTRACT().call{
            value: cancellationFee
        }("");

        /** LENDER WITHDRAW FUNDS */
        (bool success, ) = lender.call{value: amountMinusFee}("");
    }

    /*//////////////////////////////////////////////////////////////
                 PUBLIC, PRIVATE AND INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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

    function getTotalBorrowRequestCount() public view returns (uint256 count) {
        return borrowRequestCount;
    }

    function _getTokenAllocations(
        uint256 count,
        BorrowRequestDetails memory details
    )
        private
        pure
        returns (
            address[] memory tokens,
            uint256[] memory amountDeposited,
            uint256[] memory tokenValue
        )
    {
        tokens = new address[](count);
        amountDeposited = new uint256[](count);
        tokenValue = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            tokens[i] = details.tokenDetails[i].token;
            amountDeposited[i] = details.tokenDetails[i].amountDeposited;
            tokenValue[i] = details.tokenDetails[i].tokenValue;
        }

        return (tokens, amountDeposited, tokenValue);
    }

    //@audit might remove
    function isRequestPrioritized(
        uint256 requestID
    ) public view returns (bool) {
        require(requestID != 0, "invalid ID");
        BorrowRequestDetails memory details = _borrowRequestDetails[requestID];
        return details.priority;
    }

    function getBorrowerRequestsID(
        address borrower
    ) public view returns (uint256[] memory requestsID) {
        require(address(borrower) != address(0), "invalid address");
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
            uint256 requestID /*
            address[] memory tokens,
            uint256[] memory amountDeposited,
            uint256[] memory tokenvalue,*/,
            uint8 state
        )
    {
        require(requestID != 0, "invalid ID");
        BorrowRequestDetails memory details = _borrowRequestDetails[_requestID];
        // uint256 count = details.tokenDetails.length;

        // tokens = new address[](count);
        // amountDeposited = new uint256[](count);
        // tokenvalue = new uint256[](count);
        // for (uint256 i = 0; i < count; i++) {
        //     tokens[i] = details.tokenDetails[i].token;
        //     amountDeposited[i] = details.tokenDetails[i].amountDeposited;
        //     tokenvalue[i] = details.tokenDetails[i].tokenValue;
        // }

        return (
            details.borrower,
            details.amountToBorrow,
            details.priority,
            details.timeCreated,
            details.interestRate,
            details.dueDate,
            details.BreadBalance,
            details.requestID,
            /*
            tokens,
            amountDeposited,
            tokenvalue,*/
            uint8(details.state)
        );
    }

    function getLendRequestDetails(
        uint256 _requestID
    )
        public
        view
        returns (
            address lender,
            uint256 amountToLend,
            uint256 timeCreated,
            uint256 DoughBalance,
            uint256 requestID,
            uint8 state
        )
    {
        require(_requestID != 0, "invalid ID");
        LendRequestDetails memory details = _lendRequestDetails[_requestID];
        return (
            details.lender,
            details.amountToLend,
            details.timeCreated,
            details.DoughBalance,
            details.requestID,
            uint8(details.state)
        );
    }

    /*//////////////////////////////////////////////////////////////
                              PRIVATE VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // gap
    uint256[60] private __gap;
}
