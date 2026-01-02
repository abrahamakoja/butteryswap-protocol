// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title Enforcer_v1
 * @author Butteryswap Protocol
 * @notice This contract handles the execution of loan requests.
 * it gets the arrays of both borrow and lend requests and processes them in batches of 10 request at a time.
 * the batch processing ensures loans are executed in chronological order based of their block.timestamp when created.
 * this contract also implements a "priority boost" mechanism that allows users to skip the que and have their loans executed next by paying an extra fee.
 * this fee is shared amongst the protocol and the users within the loan requests that eventually seeds the priority loan.
 * this feature is experimental and may or may not be removed.
 */

// debug
import {Script, console} from "forge-std/Script.sol";

/*//////////////////////////////////////////////////////////////
                                IMPORTS
    //////////////////////////////////////////////////////////////*/

import {erc20TokenLibrary} from "./libraries/erc20TokenLibrary.sol";
import {IProtocolManager} from "./interfaces/IProtocolManager.sol";
import {ILoanManager} from "./interfaces/ILoanManager.sol";
import {IBackery} from "./interfaces/IBackery.sol";

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract Backer is
    AccessControlUpgradeable,
    ReentrancyGuardTransient,
    UUPSUpgradeable
{
    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/
    error Backer__UnAuthorized();
    /*//////////////////////////////////////////////////////////////
                                 STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    bytes32 public BACKER_ADMIN;

    address public admin;
    IProtocolManager internal ProtocolManager;
    ILoanManager internal LoanManager;
    IBackery internal Backery;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier loanManagerIsSet() {
        if (
            address(LoanManager) == address(0) ||
            address(ProtocolManager.LoanManager()) != address(LoanManager)
        ) {
            LoanManager = ILoanManager(address(ProtocolManager.LoanManager()));
            require(address(LoanManager) != address(0), "LoanManager not set");
        }
        _;
    }

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

    function initialize(address _protocolManager) public initializer {
        __AccessControl_init();
        BACKER_ADMIN = keccak256("BACKER_ADMIN");
        ProtocolManager = IProtocolManager(_protocolManager);
        admin = ProtocolManager.deployer();
        LoanManager = ILoanManager(ProtocolManager.LoanManager());
        require(admin == msg.sender); // @audit addthis to all
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(BACKER_ADMIN, msg.sender); // this would be the caller adddress of the client
        Backery = IBackery(address(0));
        ProtocolManager.updateBackerContract(address(this), admin);
    }

    function _authorizeUpgrade(
        address
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function toast()
        external
        payable
        loanManagerIsSet
        onlyRole(BACKER_ADMIN)
        nonReentrant
    {
        LoanManager.approveLoanRequests();
    }

    // gap
    uint256[60] private __gap;
}
