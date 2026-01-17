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

    struct LenderDetails {
        address[] lenders;
        uint256[] amountLended;
        uint256[] expectedReturns;
        uint256[] requestID;
    }

    struct BorrowerDetails {
        uint256 amountBorrowed;
        address borrower;
        uint256 amountToPayBack;
        uint256 requestID;
    }

    // @audit add details on amount to payback
    struct BorrowRequestDetails {
        address borrower;
        uint256 amountToBorrow;
        bool priority;
        uint256 timeCreated;
        uint256 interestRate;
        uint256 amountToPayBack;
        uint256 dueDate;
        uint256 mBreadBalance;
        uint256 requestID;
        TokenDetails[] tokenDetails;
        LoanState state;
    }
    struct LendRequestDetails {
        address lender;
        uint256 amountToLend;
        uint256 timeCreated;
        uint256 nBreadBalance;
        uint256 requestID;
        LoanState state;
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

    struct PriorityBorrow {
        address borrower;
        uint256 amountToBorrow;
        uint256 amountToPayBack;
        uint256 interestRate;
        uint256 delta;
    }

    // struct SupplyData {}

    struct SupplyData {
        uint256 expectedReturn;
        LendRequestDetails lendRequestDetails;
    }
    struct ActiveLoanDetails {
        TokenDetails[] collateral;
        SupplyData[] supplyData;
        BorrowRequestDetails borrowerRequestDetails;
        uint256 totalAmountLended;
        uint256 totalBorrowed;
        uint256 timeApproved;
        uint256 dueDate;
        uint256 activeLoanID;
    }

    /*//////////////////////////////////////////////////////////////
                           ENUMS
    //////////////////////////////////////////////////////////////*/
    enum LoanState {
        CLOSED,
        OPEN,
        ACTIVE,
        CANCELLED,
        SETTLED,
        UPDATING,
        APPROVED
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public LIMIT_MARKET;
    bytes32 public BACKER;

    address public admin;

    IProtocolManager internal ProtocolManager;

    ITokenManager internal TokenManager;

    IBackery internal Backery;

    uint256 internal normalActiveLoanCount;
    uint256 internal prioritizedActiveLoanCount;
    uint256 internal nextBorrowerID;
    uint256 internal nextLenderID;
    uint256 internal nBREAD;
    uint256 internal mBREAD;
    uint256 internal toast;
    uint256 internal crumbs;
    uint256 internal borrowRequestCount;

    uint256 internal totalBorrowRequestAmount;
    uint256 internal totalLendRequestAmount;
    uint256 internal lendRequestCount;

    Queue internal priorityQueue;
    Queue internal normalQueue;
    Queue internal supplyQueue;

    mapping(uint256 ID => ActiveLoanDetails activeLoanDetails)
        internal _activeLoanDetails;
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
    event MemeBreadMinted(
        address indexed borrower,
        uint256 indexed mBreadMinted
    );
    event ToastMinted(address indexed borrower, uint256 indexed toastMinted);
    event CrumbsMinted(address indexed lender, uint256 indexed crumbsMinted);
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
    event NativeBreadMinted(
        address indexed lender,
        uint256 indexed nBreadMinted
    );
    event BorrowQueueIncreased(uint256 indexed requestID);
    event BorrowRequestReQueued(uint256 indexed requestID);
    event BorrowQueueReduced(uint256 indexed requestID);
    event BorrowRequestCancelled(
        address indexed borrower,
        uint256 indexed requestID
    );
    event LendRequestCancelled(
        address indexed borrower,
        uint256 indexed requestID
    );
    event LendRequestReQueued(uint256 indexed requestID);

    event LendQueueIncreased(uint256 indexed requestID);
    event LendQueueReduced(uint256 indexed requestID);
    event NativeBreadBurnt(
        address indexed lender,
        uint256 indexed nBreadAmount,
        uint256 indexed requestID
    );

    event MemeBreadBurnt(
        address indexed borrower,
        uint256 indexed mBreadAmount,
        uint256 indexed requestID
    );

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
                            INITIALIZE
    //////////////////////////////////////////////////////////////*/
    function initialize(address protocolManager) public initializer {
        // @audit lock after initialize
        __AccessControl_init();
        LIMIT_MARKET = keccak256("LIMIT_MARKET");
        BACKER = keccak256("BACKER");
        ProtocolManager = IProtocolManager(protocolManager);
        TokenManager = ITokenManager(ProtocolManager.TokenManager());
        Backery = IBackery(address(0));

        admin = ProtocolManager.deployer();
        nextBorrowerID = 1;
        normalActiveLoanCount = 0;
        prioritizedActiveLoanCount = 0;
        nextLenderID = 1;
        nBREAD = 1;
        mBREAD = 2;
        toast = 3;
        crumbs = 4;
        borrowRequestCount = 0;
        totalBorrowRequestAmount = 0;
        totalLendRequestAmount = 0;
        lendRequestCount = 0;

        bool adminRoleGranted = _grantRole(DEFAULT_ADMIN_ROLE, admin);

        bool limitMarketContractRoleGranted = _grantRole(
            LIMIT_MARKET,
            ProtocolManager.LIMIT_MARKET_CONTRACT_ADDRESS()
        );

        bool backerContractRoleGranted = _grantRole(
            BACKER,
            ProtocolManager.Backer()
        );
        require(
            adminRoleGranted &&
                limitMarketContractRoleGranted &&
                backerContractRoleGranted
        );

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
        uint256 interestRate = 10e18; // @audit fix
        uint256 eligibleAmountToBorrow = collateralValue <= amountToBorrow
            ? collateralValue
            : amountToBorrow; //@audit token amounts must be formatted corrrectly in 18 decimals
        uint256 amountToPayBack = _calculateAmountToPayBack(
            interestRate,
            eligibleAmountToBorrow
        );
        borrowRequestDetails.borrower = borrower;
        borrowRequestDetails.amountToBorrow = amountToBorrow; // @audit review

        borrowRequestDetails.timeCreated = block.timestamp;
        borrowRequestDetails.interestRate = interestRate; // @audit fix
        borrowRequestDetails.dueDate = block.timestamp + 7 days; // @audit fix
        borrowRequestDetails.mBreadBalance = amountToBorrow; //@audit
        borrowRequestDetails.requestID = requestID;
        borrowRequestDetails.state = LoanState.OPEN;
        borrowRequestDetails.amountToPayBack = amountToPayBack;

        borrowerToRequestsID[borrower].push(requestID);

        totalBorrowRequestAmount += eligibleAmountToBorrow;
        borrowRequestCount++;
        nextBorrowerID++;

        console2.log("this priority before if clause is", priority);
        if (priority == true) {
            borrowRequestDetails.priority = priority;
            _enQueue(priorityQueue, requestID);
            console2.log("this priority is true", priority);
            emit BorrowRequestPrioritized(requestID);
        } else {
            borrowRequestDetails.priority = priority;
            console2.log("this priority is false", priority);
            _enQueue(normalQueue, requestID);
        }

        // @audit check ltv before proceeding
        // @audit collect fee

        /// EVENTS
        emit BorrowRequestCreated(requestID, amountToBorrow);
        emit MemeBreadMinted(borrower, eligibleAmountToBorrow);
        emit BorrowQueueIncreased(requestID);
        // mint

        Backery.mint(borrower, mBREAD, amountToBorrow * 1 ether); //@audit overflow?

        // Backery.transferFrom(borrower, address(ProtocolManager), 1, 1);
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
            borrowRequestDetails.state == LoanState.OPEN,
            "loan state invalid"
        );
        //  checks position hasnt been skipped if yes re-assign next
        // change state
        borrowRequestDetails.state = LoanState.UPDATING;

        borrowRequestDetails.priority = true;

        _enQueue(priorityQueue, requestID);
        // EVENTS
        emit BorrowRequestPrioritized(requestID);
        // @audit understand dequeeue first
        borrowRequestDetails.state == LoanState.OPEN;
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
            borrowRequestDetails.state == LoanState.OPEN,
            "loan state invalid"
        );
        // change state
        borrowRequestDetails.state = LoanState.UPDATING;

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
        emit MemeBreadMinted(borrower, eligibleAmountToBorrow);
        // @audit collect fee
        // mints additional mBREAD
        Backery.mint(borrower, mBREAD, eligibleAmountToBorrow * 1 ether); //@audit overflow?

        borrowRequestDetails.state == LoanState.OPEN;
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
            borrowRequestDetails.state == LoanState.OPEN,
            "loan state invalid"
        );
        // // change state
        borrowRequestDetails.state = LoanState.UPDATING;
        // reset request values
        uint256 mBreadBalance = borrowRequestDetails.mBreadBalance;

        borrowRequestDetails.dueDate = 0; // @audit fix
        borrowRequestDetails.mBreadBalance = 0;
        borrowRequestDetails.state = LoanState.CANCELLED;
        totalBorrowRequestAmount -= borrowRequestDetails.amountToBorrow;
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
        emit BorrowRequestCancelled(borrower, requestID);
        emit BorrowQueueReduced(requestID);
        emit MemeBreadBurnt(borrower, mBREAD, requestID);

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

        require(mBreadBalance == _tokenValue, "balance mismatch");

        // burn mBREAD
        Backery.burn(borrower, mBREAD, mBreadBalance);

        console2.log("boorower", borrowRequestDetails.borrower);
        console2.log("mBREAD balance", borrowRequestDetails.mBreadBalance);
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
        uint256 amountToLend = msg.value; // @audit handle fee
        // update mapping
        LendRequestDetails storage lendRequestDetails = _lendRequestDetails[
            requestID
        ];
        lendRequestDetails.lender = lender;
        lendRequestDetails.amountToLend = amountToLend;
        lendRequestDetails.timeCreated = block.timestamp;
        lendRequestDetails.nBreadBalance = amountToLend;
        lendRequestDetails.requestID = requestID;
        lendRequestDetails.state = LoanState.OPEN;
        totalLendRequestAmount += amountToLend;
        lendRequestCount++;

        // _lendRequestDetails[requestID] = lendRequestDetails;
        lenderToRequestsID[lender].push(requestID);
        // update lend count
        nextLenderID++;

        // add to queue
        _enQueue(supplyQueue, requestID);

        // emit event
        emit LendRequestCreated(requestID, amountToLend);
        emit NativeBreadMinted(lender, amountToLend);
        emit LendQueueIncreased(requestID);

        // transfer eth to this address
        console2.log("lend time", lendRequestDetails.timeCreated);
        console2.log("lend amount", lendRequestDetails.amountToLend);

        console2.log(
            "fee contract balance before",
            address(ProtocolManager.FEE_CONTRACT()).balance
        );
        console2.log("contract balance after", address(this).balance);
        // (bool originationFeePaid, ) = ProtocolManager.FEE_CONTRACT().call{
        //     value: originationFee
        // }(""); // @audit fix fee
        (bool success, ) = address(this).call{value: amountToLend}("");
        // require(originationFeePaid && success);
        console2.log(
            "fee contract balance after",
            address(ProtocolManager.FEE_CONTRACT()).balance
        );

        // mint nBREAD to lender
        Backery.mint(lender, nBREAD, amountToLend);
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
            lendRequestDetails.state == LoanState.OPEN,
            "loan state invalid"
        );
        lendRequestDetails.state = LoanState.UPDATING;

        uint256 nBreadBalance = lendRequestDetails.nBreadBalance;
        uint256 amountToLend = lendRequestDetails.amountToLend;
        uint256 cancellationFee = 1;
        uint256 amountMinusFee = msg.value - cancellationFee;

        lendRequestDetails.nBreadBalance = 0;
        lendRequestDetails.state = LoanState.CANCELLED;
        totalLendRequestAmount -= amountToLend;
        lendRequestCount--;
        /** EFFECTS */

        // remove from queue
        _removeFromQueue(supplyQueue, requestID);
        require(nBreadBalance == amountToLend, "balance mismatch");

        //  @audit emit events
        emit LendQueueReduced(requestID);
        emit LendRequestCancelled(lender, requestID);
        emit NativeBreadBurnt(lender, nBREAD, requestID);

        // burn nBREAD
        Backery.burn(lender, nBREAD, nBreadBalance);

        // /** COLLECT CANCELLATION FEE */
        (bool feePaid, ) = ProtocolManager.FEE_CONTRACT().call{
            value: cancellationFee
        }("");

        /** LENDER WITHDRAW FUNDS */
        (bool success, ) = lender.call{value: amountMinusFee}("");
    }

    /*//////////////////////////////////////////////////////////////
                             TOAST FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function approveLoanRequests2()
        external
        payable
        backeryIsSet
        onlyRole(BACKER)
        nonReentrant
        returns (uint256 normalActiveLoanID, uint256 prioritizedActiveLoanID)
    {
        //    should never revert
        if (totalLendRequestAmount == 0) {
            console2.log("liquidity low");
            return (0, 0);
        }

        prioritizedActiveLoanID = _createPrioritizedActiveLoan();
        console2.log("prioritizedActiveLoanID ", prioritizedActiveLoanID);
        normalActiveLoanID = _createNormalActiveLoan();
        console2.log("normalActiveLoanID ", normalActiveLoanID);

        return (normalActiveLoanID, prioritizedActiveLoanID);
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

    function _peek(
        Queue storage q,
        uint256 index
    ) internal returns (uint256 ID) {
        ID = q.nodes[index].next;

        return ID;
    }

    function _deQueue(Queue storage q) private returns (uint256 ID) {
        ID = q.head;
        if (ID == 0) {
            console2.log("triggered 3", q.head);
            return 0;
        }
        // require(ID != 0, "empty Queue");

        uint next = q.nodes[ID].next;

        q.head = next;

        if (next != 0) {
            q.nodes[next].prev = 0;
        } else {
            q.tail = 0;
        }

        delete q.nodes[ID];
    }

    function _createPrioritizedActiveLoan()
        internal
        returns (uint256 activeID)
    {
        // @bookmark @audit this is where the memory issue begin
        prioritizedActiveLoanCount++;
        activeID = prioritizedActiveLoanCount;

        uint256 priorityBorrowRequest = _deQueue(priorityQueue);

        BorrowRequestDetails
            storage priorityBorrowRequestDetails = _borrowRequestDetails[
                priorityBorrowRequest
            ];

        ActiveLoanDetails
            storage prioritizedActiveLoanDetails = _activeLoanDetails[activeID];
        // check state
        // process priorityBorrowRequest data
        LoanState prioritizedBorrowRequestState = priorityBorrowRequestDetails
            .state;

        if (
            priorityBorrowRequest == 0 &&
            prioritizedBorrowRequestState != LoanState.OPEN
        ) {
            emit BorrowRequestReQueued(priorityBorrowRequest);
            // re-queue to the end of the list
            _enQueue(priorityQueue, priorityBorrowRequest);

            activeID = 0;
            return activeID;
        }

        // change state
        priorityBorrowRequestDetails.state = LoanState.UPDATING;

        // get relevant borrow request values
        address borrower = priorityBorrowRequestDetails.borrower;

        uint256 amountToBorrow = priorityBorrowRequestDetails.amountToBorrow;
        console2.log("amount to borrow", amountToBorrow);
        uint256 amountToPayBack = amountToBorrow + 1 ether; // @audit fix this
        uint256 interestRate = priorityBorrowRequestDetails.interestRate;
        uint256 lendersNeeded = _getNumberOfLendersNeeded({
            amountToBorrow: amountToBorrow
        });

        console2.log(" lendersNeeded", lendersNeeded);

        SupplyData[] memory supplyData = new SupplyData[](lendersNeeded);
        for (uint i = 0; i < lendersNeeded; i++) {
            uint256 amountLended;
            uint256 supplyID = _deQueue(supplyQueue);

            supplyData[i].lendRequestDetails = _lendRequestDetails[supplyID];
            console2.log(
                "this is new lender",
                supplyData[i].lendRequestDetails.lender
            );

            // check state/ skip if state is closed
            if (supplyData[i].lendRequestDetails.state != LoanState.OPEN) {
                // re-queue to the end of the list
                _enQueue(
                    supplyQueue,
                    supplyData[i].lendRequestDetails.requestID
                );
                emit LendRequestReQueued({
                    requestID: supplyData[i].lendRequestDetails.requestID
                });
                break;
            }
            // proceed if state is open

            // check delta between borrow amount and available liquidity
            // determins if more than one lend request would be needed to setlle the borrow request
            uint256 amountTolend = supplyData[i]
                .lendRequestDetails
                .amountToLend;
            console2.log("amount amountTolend", amountTolend);

            amountLended = supplyData[i].lendRequestDetails.amountToLend;
            prioritizedActiveLoanDetails.totalAmountLended += amountLended;

            prioritizedActiveLoanDetails.supplyData.push(supplyData[i]);
        }
        console2.log(
            "final amount lended",
            prioritizedActiveLoanDetails.totalAmountLended
        );

        uint counter = prioritizedActiveLoanDetails.supplyData.length;

        // populate the active loan struct
        // collateral details
        prioritizedActiveLoanDetails.collateral = priorityBorrowRequestDetails
            .tokenDetails;

        // update borrower Details
        // borrower
        prioritizedActiveLoanDetails.borrowerRequestDetails.borrower = borrower;
        // amount borrowed
        prioritizedActiveLoanDetails
            .borrowerRequestDetails
            .amountToBorrow = amountToBorrow;
        // amount to pay back
        prioritizedActiveLoanDetails
            .borrowerRequestDetails
            .amountToPayBack = amountToPayBack;
        // borrow request ID
        prioritizedActiveLoanDetails
            .borrowerRequestDetails
            .requestID = priorityBorrowRequest;

        // time of approval
        prioritizedActiveLoanDetails.timeApproved = block.timestamp;
        // due date for loan repayment
        prioritizedActiveLoanDetails.dueDate = block.timestamp + 7 days; // @audit fix later
        // active loan ID
        prioritizedActiveLoanDetails.activeLoanID = prioritizedActiveLoanCount;

        // update lenders data
        // prioritizedActiveLoanDetails.supplyData = supplyData;

        uint256 count = prioritizedActiveLoanDetails.supplyData.length;
        console2.log(
            "before looper ??",
            prioritizedActiveLoanDetails.supplyData.length,
            count
        );
        for (uint256 i = 0; i < count; i++) {
            // lender
            address lender = prioritizedActiveLoanDetails
                .supplyData[i]
                .lendRequestDetails
                .lender;
            // amount to lend
            uint256 amountToLend = prioritizedActiveLoanDetails
                .supplyData[i]
                .lendRequestDetails
                .amountToLend;
            // expected return
            uint256 expectedReturn = _calculateProfitOnLend(
                interestRate,
                amountToLend
            );
            // update lend request state
            prioritizedActiveLoanDetails
                .supplyData[i]
                .lendRequestDetails
                .state = LoanState.APPROVED;

            console2.log("looper +++++", lender, i);
            emit CrumbsMinted(lender, expectedReturn);
            // mint crumbs to lender
            Backery.mint({to: lender, id: crumbs, amount: expectedReturn}); //@audit
        }

        // settle borrower
        // emit events
        emit ToastMinted(borrower, amountToBorrow);
        // update borrowrequest state
        prioritizedActiveLoanDetails.borrowerRequestDetails.state = LoanState
            .APPROVED;

        // mint crumbs to lender
        Backery.mint({to: borrower, id: toast, amount: amountToBorrow}); //@audit overflow?

        console2.log("activeID <<<<", activeID);
        return activeID;
    }
    function _createNormalActiveLoan() internal returns (uint256 activeID) {
        // @bookmark @audit this is where the memory issue begin
        normalActiveLoanCount++;
        activeID = normalActiveLoanCount;
        console2.log("normalActiveLoanCount <<<<", normalActiveLoanCount);
        console2.log("activeID <<<<", activeID);
        uint256 normalBorrowRequest = _deQueue(priorityQueue);
        console2.log("normalBorrowRequest <<<<", normalBorrowRequest);

        BorrowRequestDetails
            storage normalBorrowRequestDetails = _borrowRequestDetails[
                normalBorrowRequest
            ];

        ActiveLoanDetails
            storage prioritizedActiveLoanDetails = _activeLoanDetails[activeID];
        // check state
        // process priorityBorrowRequest data
        LoanState normalBorrowRequestState = normalBorrowRequestDetails.state;

        if (
            normalBorrowRequest == 0 &&
            normalBorrowRequestState != LoanState.OPEN
        ) {
            emit BorrowRequestReQueued(normalBorrowRequest);
            // re-queue to the end of the list
            _enQueue(priorityQueue, normalBorrowRequest);

            activeID = 0;
            return activeID;
        }

        // change state
        normalBorrowRequestDetails.state = LoanState.UPDATING;

        // get relevant borrow request values
        address borrower = normalBorrowRequestDetails.borrower;

        uint256 amountToBorrow = normalBorrowRequestDetails.amountToBorrow;
        console2.log("amount to borrow", amountToBorrow);
        uint256 amountToPayBack = amountToBorrow + 1 ether; // @audit fix this
        uint256 interestRate = normalBorrowRequestDetails.interestRate;
        uint256 lendersNeeded = _getNumberOfLendersNeeded({
            amountToBorrow: amountToBorrow
        });

        console2.log(" lendersNeeded", lendersNeeded);

        SupplyData[] memory supplyData = new SupplyData[](lendersNeeded);
        for (uint i = 0; i < lendersNeeded; i++) {
            uint256 amountLended;
            uint256 supplyID = _deQueue(supplyQueue);

            supplyData[i].lendRequestDetails = _lendRequestDetails[supplyID];
            console2.log(
                "this is new lender",
                supplyData[i].lendRequestDetails.lender
            );

            // check state/ skip if state is closed
            if (supplyData[i].lendRequestDetails.state != LoanState.OPEN) {
                // re-queue to the end of the list
                _enQueue(
                    supplyQueue,
                    supplyData[i].lendRequestDetails.requestID
                );
                emit LendRequestReQueued({
                    requestID: supplyData[i].lendRequestDetails.requestID
                });
                break;
            }
            // proceed if state is open

            // check delta between borrow amount and available liquidity
            // determins if more than one lend request would be needed to setlle the borrow request
            uint256 amountTolend = supplyData[i]
                .lendRequestDetails
                .amountToLend;
            console2.log("amount amountTolend", amountTolend);

            amountLended = supplyData[i].lendRequestDetails.amountToLend;
            prioritizedActiveLoanDetails.totalAmountLended += amountLended;

            prioritizedActiveLoanDetails.supplyData.push(supplyData[i]);
        }
        console2.log(
            "final amount lended",
            prioritizedActiveLoanDetails.totalAmountLended
        );

        uint counter = prioritizedActiveLoanDetails.supplyData.length;

        // populate the active loan struct
        // collateral details
        prioritizedActiveLoanDetails.collateral = normalBorrowRequestDetails
            .tokenDetails;

        // update borrower Details
        // borrower
        prioritizedActiveLoanDetails.borrowerRequestDetails.borrower = borrower;
        // amount borrowed
        prioritizedActiveLoanDetails
            .borrowerRequestDetails
            .amountToBorrow = amountToBorrow;
        // amount to pay back
        prioritizedActiveLoanDetails
            .borrowerRequestDetails
            .amountToPayBack = amountToPayBack;
        // borrow request ID
        prioritizedActiveLoanDetails
            .borrowerRequestDetails
            .requestID = normalBorrowRequest;

        // time of approval
        prioritizedActiveLoanDetails.timeApproved = block.timestamp;
        // due date for loan repayment
        prioritizedActiveLoanDetails.dueDate = block.timestamp + 7 days; // @audit fix later
        // active loan ID
        prioritizedActiveLoanDetails.activeLoanID = prioritizedActiveLoanCount;

        // update lenders data
        // prioritizedActiveLoanDetails.supplyData = supplyData;

        uint256 count = prioritizedActiveLoanDetails.supplyData.length;
        console2.log(
            "before looper ??",
            prioritizedActiveLoanDetails.supplyData.length,
            count
        );
        for (uint256 i = 0; i < count; i++) {
            // lender
            address lender = prioritizedActiveLoanDetails
                .supplyData[i]
                .lendRequestDetails
                .lender;
            // amount to lend
            uint256 amountToLend = prioritizedActiveLoanDetails
                .supplyData[i]
                .lendRequestDetails
                .amountToLend;
            // expected return
            uint256 expectedReturn = _calculateProfitOnLend(
                interestRate,
                amountToLend
            );
            // update lend request state
            prioritizedActiveLoanDetails
                .supplyData[i]
                .lendRequestDetails
                .state = LoanState.APPROVED;

            console2.log("looper +++++", lender, i);
            emit CrumbsMinted(lender, expectedReturn);
            // mint crumbs to lender
            Backery.mint({to: lender, id: crumbs, amount: expectedReturn}); //@audit
        }

        // settle borrower
        // emit events
        emit ToastMinted(borrower, amountToBorrow);
        // update borrowrequest state
        prioritizedActiveLoanDetails.borrowerRequestDetails.state = LoanState
            .APPROVED;

        // mint crumbs to lender
        Backery.mint({to: borrower, id: toast, amount: amountToBorrow}); //@audit overflow?

        console2.log("activeID <<<<", activeID);
        return activeID;
    }

    function _calculateAmountToPayBack(
        uint256 interestRate,
        uint256 amountToBorrow
    ) private pure returns (uint256 amountToPayBack) {
        return (amountToBorrow * 100) / interestRate; //@audit fix
    }

    function _calculateProfitOnLend(
        uint256 interestRate,
        uint256 amountToLend
    ) private pure returns (uint256 potentialProfit) {
        return (amountToLend * 100) / interestRate; // @audit fix
    }

    function _getNumberOfLendersNeeded(
        uint256 amountToBorrow
    ) internal view returns (uint256 lendersNeeded) {
        uint256 tmpAmount = amountToBorrow;

        uint256 current = supplyQueue.head;
        if (current == 0) return 0;

        LendRequestDetails storage first = _lendRequestDetails[current];
        if (first.state == LoanState.OPEN && first.amountToLend >= tmpAmount) {
            return 1;
        }

        while (current != 0 && tmpAmount != 0) {
            LendRequestDetails storage lend = _lendRequestDetails[current];

            if (lend.state != LoanState.OPEN) break;

            lendersNeeded++;
            if (lend.amountToLend >= tmpAmount) {
                break; // this lender finishes the borrow
            }
            tmpAmount -= lend.amountToLend;

            current = supplyQueue.nodes[current].next;
        }

        return lendersNeeded;
    }

    function _appendData(
        uint256 lendersCount,
        SupplyData memory lenderData
    ) internal returns (SupplyData[] memory data) {
        data = new SupplyData[](lendersCount + 1);
        uint256 totalAmountLended;
        uint256 n = 1;

        for (uint256 i = 0; i < n; i++) {
            console2.log(
                " >>info ",
                lendersCount,
                i,
                lenderData.lendRequestDetails.lender
            );
            data[lendersCount] = lenderData;
            totalAmountLended += lenderData.lendRequestDetails.amountToLend;
        }
        return data;
    }

    /*//////////////////////////////////////////////////////////////
                  PRIVATE/ PUBLIC PURE/VIEW FUNCTIONS
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
    function getBorrowRequestTokenDetails(
        uint256 requestID
    )
        external
        view
        returns (
            address[] memory tokens,
            uint256[] memory amountDeposited,
            uint256[] memory tokenValue
        )
    {
        BorrowRequestDetails memory details = _borrowRequestDetails[requestID];
        uint256 count = details.tokenDetails.length;
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

    function getBorrowerRequestTokenBalance(
        uint256 requestID
    )
        external
        view
        returns (address[] memory tokens, uint256[] memory balance)
    {
        BorrowRequestDetails memory details = _borrowRequestDetails[requestID];
        uint256 count = details.tokenDetails.length;
        address borrower = details.borrower;
        tokens = new address[](count);
        balance = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            tokens[i] = details.tokenDetails[i].token;
            balance[i] = erc20TokenLibrary.getBalance(
                borrower,
                details.tokenDetails[i].token
            );
        }

        return (tokens, balance);
    }

    function getActiveLoanRequest(uint256 normalActiveLoanID) external view {
        ActiveLoanDetails memory activeLoanDetails = _activeLoanDetails[
            normalActiveLoanID
        ];

        address token;
        token = activeLoanDetails.collateral[0].token;
        console2.log(token);
        console2.log(activeLoanDetails.borrowerRequestDetails.amountToPayBack);
        console2.log(normalActiveLoanID);
    }

    function getBorrowRequestDetails(
        uint256 _requestID
    )
        external
        view
        returns (
            address borrower,
            uint256 amountToBorrow,
            bool priority,
            uint256 timeCreated,
            uint256 interestRate,
            uint256 dueDate,
            uint256 mBreadBalance,
            uint256 requestID,
            uint8 state
        )
    {
        require(_requestID != 0, "invalid ID");
        BorrowRequestDetails memory details = _borrowRequestDetails[_requestID];

        return (
            details.borrower,
            details.amountToBorrow,
            details.priority,
            details.timeCreated,
            details.interestRate,
            details.dueDate,
            details.mBreadBalance,
            details.requestID,
            uint8(details.state)
        );
    }

    function getLendRequestDetails(
        uint256 _requestID
    )
        external
        view
        returns (
            address lender,
            uint256 amountToLend,
            uint256 timeCreated,
            uint256 nBreadBalance,
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
            details.nBreadBalance,
            details.requestID,
            uint8(details.state)
        );
    }

    /*//////////////////////////////////////////////////////////////
                              GAP
    //////////////////////////////////////////////////////////////*/

    uint256[60] private __gap;
}
