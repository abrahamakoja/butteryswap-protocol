// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IProtocolManager} from "./interfaces/IProtocolManager.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC6909Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC6909/ERC6909Upgradeable.sol";
import {ERC6909MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC6909/extensions/ERC6909MetadataUpgradeable.sol";
import {ERC6909TokenSupplyUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC6909/extensions/ERC6909TokenSupplyUpgradeable.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract Backery is
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ERC6909Upgradeable,
    ERC6909MetadataUpgradeable,
    ERC6909TokenSupplyUpgradeable,
    ReentrancyGuardTransient
{
    bytes32 private LOAN_MANAGER;
    uint256 private DOUGH; // lenders
    uint256 private BREAD; // borrowers
    address public admin;

    IProtocolManager ProtocolManager;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address protocolManager) public initializer {
        __AccessControl_init();
        __ERC6909_init();
        __ERC6909Metadata_init();
        __ERC6909TokenSupply_init();

        LOAN_MANAGER = keccak256("LOAN_MANAGER");
        ProtocolManager = IProtocolManager(protocolManager);

        admin = ProtocolManager.deployer();

        bool adminRoleGranted = _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        bool loanManagerRoleGranted = _grantRole(
            LOAN_MANAGER,
            ProtocolManager.LoanManager()
        );
        require(adminRoleGranted && loanManagerRoleGranted, "grantRole failed");

        DOUGH = 1;
        BREAD = 2;

        TokenMetadata memory doughMetaData = TokenMetadata({
            name: "Dough",
            symbol: "DOUGH",
            decimals: 18
        });
        TokenMetadata memory breadMetaData = TokenMetadata({
            name: "Bread",
            symbol: "BREAD",
            decimals: 18
        });

        _setName(DOUGH, doughMetaData.name);
        _setSymbol(DOUGH, doughMetaData.symbol);
        _setDecimals(DOUGH, doughMetaData.decimals);

        _setName(BREAD, breadMetaData.name);
        _setSymbol(BREAD, breadMetaData.symbol);
        _setDecimals(BREAD, breadMetaData.decimals);

        ProtocolManager.updateBackeryContract(address(this), admin);
    }

    function mint(address to, uint256 id, uint256 amount) external {
        _mint(to, id, amount);
    }
    function getTokenMetadata(
        uint256 ID
    ) external view returns (TokenMetadata memory tokenMetadata) {
        return
            tokenMetadata = TokenMetadata({
                name: name(ID),
                symbol: symbol(ID),
                decimals: decimals(ID)
            });
    }
    // initializers
    function _authorizeUpgrade(
        address
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    function _update(
        address from,
        address to,
        uint256 id,
        uint256 amount
    )
        internal
        override(ERC6909Upgradeable, ERC6909TokenSupplyUpgradeable)
        onlyRole(LOAN_MANAGER)
    {}

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(AccessControlUpgradeable, ERC6909Upgradeable, IERC165)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // gap
    uint256[60] private __gap;
}
