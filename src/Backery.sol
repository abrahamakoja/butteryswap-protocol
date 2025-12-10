// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC6909Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC6909/ERC6909Upgradeable.sol";
import {ERC6909MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC6909/extensions/ERC6909MetadataUpgradeable.sol";
import {ERC6909TokenSupplyUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC6909/extensions/ERC6909TokenSupplyUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Backery is
    ERC6909Upgradeable,
    ERC6909MetadataUpgradeable,
    ERC6909TokenSupplyUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuard
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // --------------------
    // Initialization
    // --------------------

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC6909_init();
        __ERC6909Metadata_init();
        __ERC6909TokenSupply_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    // --------------------
    // Bread (borrower) functions
    // --------------------
    function mintBread(
        address to,
        uint256 breadId,
        uint256 amount
    ) external onlyRole(ADMIN_ROLE) {
        _mint(to, breadId, amount);
        // _increaseTotalSupply(breadId, amount);
    }

    function burnBread(
        address from,
        uint256 breadId,
        uint256 amount
    ) external onlyRole(ADMIN_ROLE) {
        _burn(from, breadId, amount);
        // _decreaseTotalSupply(breadId, amount);
    }

    function setBreadMetadata(
        uint256 breadId,
        string calldata metadata
    ) external onlyRole(ADMIN_ROLE) {
        // _setTokenMetadata(breadId, metadata);
    }

    // function breadMetadata(
    //     uint256 breadId
    // ) external view returns (string memory) {
    //     return _tokenMetadata(breadId);
    // }

    // --------------------
    // Crumbs (lender) functions
    // --------------------
    function mintCrumbs(
        address to,
        uint256 crumbsId,
        uint256 amount
    ) external onlyRole(ADMIN_ROLE) {
        _mint(to, crumbsId, amount);
        // _increaseTotalSupply(crumbsId, amount);
    }

    function burnCrumbs(
        address from,
        uint256 crumbsId,
        uint256 amount
    ) external onlyRole(ADMIN_ROLE) {
        _burn(from, crumbsId, amount);
        // _decreaseTotalSupply(crumbsId, amount);
    }

    // function setCrumbsMetadata(
    //     uint256 crumbsId,
    //     string calldata metadata
    // ) external onlyRole(ADMIN_ROLE) {
    //     _setTokenMetadata(crumbsId, metadata);
    // }

    function crumbsMetadata(
        uint256 crumbsId
    ) external view returns (string memory) {
        return _tokenMetadata(crumbsId);
    }

    // --------------------
    // ERC6909 support functions
    // --------------------
    function exists(uint256 tokenId) public view returns (bool) {
        return totalSupply(tokenId) > 0;
    }

    // --------------------
    // UUPS upgrade authorization
    // --------------------
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(ADMIN_ROLE) {}
}
