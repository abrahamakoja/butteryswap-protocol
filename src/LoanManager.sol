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

    struct ActiveLoanDetails {
        CollateralDetails collateralDetails;
        BorrowerDetails borrowerDetails;
        LenderDetails[] lenderDetails;
        uint256 timeApproved;
        uint256 dueDate;
    }

    struct LenderDetails {
        address lender;
        uint256 amountLended;
        uint256 expectedReturn;
        uint256 requestID;
    }

    struct CollateralDetails {
        TokenDetails[] tokenDetails;
    }

    struct BorrowerDetails {
        uint256 amountBorrowed;
        address borrower;
        uint256 amountToPayBack;
        uint256 requestID;
    }

    struct BorrowRequestDetails {
        address borrower;
        uint256 amountToBorrow;
        bool priority;
        uint256 timeCreated;
        uint256 interestRate;
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

    /*//////////////////////////////////////////////////////////////
                           ENUMS
    //////////////////////////////////////////////////////////////*/
    enum LoanState {
        CLOSED,
        OPEN,
        ACTIVE,
        CANCELLED,
        SETTLED,
        UPDATING
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

    uint256 internal activeLoanCount;
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
        activeLoanCount = 0;
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

        uint256 eligibleAmountToBorrow = collateralValue <= amountToBorrow
            ? collateralValue
            : amountToBorrow; //@audit token amounts must be formatted corrrectly in 18 decimals
        borrowRequestDetails.borrower = borrower;
        borrowRequestDetails.amountToBorrow = eligibleAmountToBorrow;
        borrowRequestDetails.priority = priority;
        borrowRequestDetails.timeCreated = block.timestamp;
        borrowRequestDetails.interestRate = 10e18; // @audit fix
        borrowRequestDetails.dueDate = block.timestamp + 7 days; // @audit fix
        borrowRequestDetails.mBreadBalance = eligibleAmountToBorrow;
        borrowRequestDetails.requestID = requestID;
        borrowRequestDetails.state = LoanState.OPEN;

        borrowerToRequestsID[borrower].push(requestID);

        totalBorrowRequestAmount += eligibleAmountToBorrow;
        borrowRequestCount++;
        nextBorrowerID++;

        console2.log("this priority", priority);
        if (priority) {
            _enQueue(priorityQueue, requestID);
            emit BorrowRequestPrioritized(requestID);
        } else {
            _enQueue(normalQueue, requestID);
        }

        // @audit check ltv before proceeding
        // @audit collect fee

        /// EVENTS
        emit BorrowRequestCreated(requestID, amountToBorrow);
        emit MemeBreadMinted(borrower, eligibleAmountToBorrow);
        emit BorrowQueueIncreased(requestID);
        // mint

        Backery.mint(borrower, mBREAD, eligibleAmountToBorrow * 1 ether); //@audit overflow?

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
        uint256 amountToLend = msg.value - originationFee;
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

    function approveLoanRequests()
        external
        payable
        backeryIsSet
        onlyRole(BACKER)
        nonReentrant
        returns (uint256 activeLoanID)
    {
        //    should never revert
        if (totalBorrowRequestAmount > totalLendRequestAmount) {
            console2.log("liquidity low");
            return 0;
        }
        activeLoanCount++;
        activeLoanID = activeLoanCount;
        LendRequestDetails storage lendRequestDetails;
        BorrowRequestDetails storage borrowRequestDetails;
        ActiveLoanDetails storage activeLoanDetails = _activeLoanDetails[
            activeLoanID
        ];

        console2.log("activeLoanID", activeLoanID);
        console2.log("activeLoanCount", activeLoanCount);

        // get borrow request
        uint256 lendRequest = _deQueue(supplyQueue);
        uint256 borrowRequest = _deQueue(normalQueue);
        console2.log("borrowRequest", borrowRequest);

        //  lend request check
        if (lendRequest == 0) {
            console2.log("lendRequest 2", lendRequest);

            // check  list again
            lendRequest = _deQueue(priorityQueue);
            lendRequestDetails = _lendRequestDetails[lendRequest];
            if (lendRequestDetails.state != LoanState.OPEN) {
                // requeue
                _enQueue(supplyQueue, lendRequest);
                emit LendRequestReQueued(lendRequest);
                return 0; //break
            }
            console2.log("lend lendRequest if clause", lendRequest);
        } else {
            lendRequestDetails = _lendRequestDetails[lendRequest];
            // check and change state
            if (lendRequestDetails.state != LoanState.OPEN) {
                // requeue
                _enQueue(supplyQueue, lendRequest);
                emit LendRequestReQueued(lendRequest);
                return 0; //break
            }
            console2.log("normal triggerd", lendRequest);
        }

        // borrow request check
        if (borrowRequest == 0) {
            console2.log("triggered 2", borrowRequest);

            // check priority list
            borrowRequest = _deQueue(priorityQueue);
            borrowRequestDetails = _borrowRequestDetails[borrowRequest];
            if (borrowRequestDetails.state != LoanState.OPEN) {
                // requeue
                _enQueue(priorityQueue, borrowRequest);
                emit BorrowRequestReQueued(borrowRequest);
                return 0; //break
            }
            console2.log("triggered prioritized", borrowRequest);
        } else {
            borrowRequestDetails = _borrowRequestDetails[borrowRequest];
            // check and change state
            if (borrowRequestDetails.state != LoanState.OPEN) {
                // requeue
                _enQueue(normalQueue, borrowRequest);
                emit BorrowRequestReQueued(borrowRequest);
            }
            console2.log("normal triggerd", borrowRequest);
        }

        lendRequestDetails.state = LoanState.UPDATING;
        borrowRequestDetails.state = LoanState.UPDATING;

        // get relevant borrow request values
        uint256 amountToBorrow = borrowRequestDetails.amountToBorrow;
        address borrower = borrowRequestDetails.borrower;
        uint256 borrowerRequestID = borrowRequestDetails.requestID;

        // get relevant lend request values
        uint256 amountToLend = lendRequestDetails.amountToLend;
        address lender = lendRequestDetails.lender;
        uint256 lenderRequestID = lendRequestDetails.requestID;

        // check delta between borrow amount and available liquidity
        uint256 delta = amountToBorrow < amountToLend
            ? 0
            : amountToBorrow - amountToLend;

        // mint to borrow if delta is 0
        if (delta == 0) {
            uint256 amountToPayBack = amountToBorrow +
                borrowRequestDetails.interestRate;
            uint256 lDelta = lendRequestDetails.amountToLend - amountToBorrow;

            // update lender request state
            if (lDelta > 0) {
                lendRequestDetails.state = LoanState.OPEN;
            } else {
                lendRequestDetails.state = LoanState.SETTLED;
            }

            // update borrower request state
            borrowRequestDetails.state = LoanState.SETTLED;

            // fetch LenderDetails
            LenderDetails memory lenderDetails;
            lenderDetails.lender = lender;
            lenderDetails.amountLended = amountToLend;
            lenderDetails.expectedReturn = amountToPayBack;
            lenderDetails.requestID = lenderRequestID;

            // populate the active loan struct

            // collateral details
            activeLoanDetails
                .collateralDetails
                .tokenDetails = borrowRequestDetails.tokenDetails;

            // borrower Details
            activeLoanDetails.borrowerDetails.amountBorrowed = amountToBorrow;
            activeLoanDetails.borrowerDetails.borrower = borrower;
            activeLoanDetails.borrowerDetails.amountToPayBack = amountToPayBack;
            activeLoanDetails.borrowerDetails.requestID = borrowerRequestID;

            // lender details
            activeLoanDetails.lenderDetails.push(lenderDetails);
            activeLoanDetails.timeApproved = block.timestamp;
            activeLoanDetails.dueDate = block.timestamp + 7 days; // @audit fix later

            // emit events
            emit ToastMinted(borrower, amountToBorrow);
            emit CrumbsMinted(lender, amountToPayBack);
            // mint toast to borrower
            Backery.mint(borrower, toast, amountToBorrow); //@audit overflow?
            // mint crumbs to lender
            Backery.mint(lender, crumbs, amountToPayBack); //@audit overflow?
        } else {
            // fetch more lend request that can collectively satisfy the borrow request
            // use the number to bound a for loop
            // process loan
        }
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

    function getActiveLoanRequest(uint256 activeLoanID) external view {
        ActiveLoanDetails memory activeLoanDetails = _activeLoanDetails[
            activeLoanID
        ];
        // tokens = new address[](1);
        // tokens = activeLoanDetails.collateralDetails.tokenDetails[0].token;
        console2.log(activeLoanDetails.collateralDetails.tokenDetails[5].token);
        console2.log(activeLoanID);
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
        public
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
                              PRIVATE VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // gap
    uint256[60] private __gap;
}
