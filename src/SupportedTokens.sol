// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SupportedTokens
 * @author Abraham akoja
 * @notice This contract stores the list of supported ERC20 tokens for the ButterySwap protocol.
 * this contract handles the logic for adding new tokens, deleting listed tokens,validating and managing the healthFactor of all ERC20 tokens interacting with the Butteryswap protocol.
 */


////////////////
/// Imports ///
//////////////

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import  {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SupportedTokens is ReentrancyGuard {
    // errors
    // interfaces, libraries, contracts

    //////////////////////////
    /// Type Declarations ///
    ////////////////////////

/// @notice This struct stores the token details.
/// @dev This is only updated when the "addToken()" function is called.
/// @param dev stores the address of the "addtoken()" function caller.
/// @param feeAddresess stores the whitelisted address(es) to recieve fees on the listed token.
/// @param timeListed stores the block.timestamp of the token when it was listed.
    struct tokenDetails {
         address dev;
         address[] feeAddresess;
         uint256 timeListed;
    }

    ////////////////////////
    /// State variables ///
    //////////////////////

    /// @dev Array of addresses storing a list of supported tokens.
    address[] private s_supportedTokens;
    /// @dev Private variable of the listing fee to be paid by caller when calling "addToken()".
    private private s_listingFee;
    /// @dev Mapping of token address to token details struct.
    mapping(address tokenAddress => tokenDetails _tokenDetails) private s_tokenDetails;

    // Events
    // Modifiers

    //////////////////
    /// Functions ///
    ////////////////
    // constructor
    constructor() {}

    // receive function (if exists)
    // fallback function (if exists)

    //////////////////////////
    ///External Functions ///
    ////////////////////////

    /*
     * @param tokenAddress: The ERC20 token address of the caller wishes to get listed.
     * @notice This function alllows caller to add an ERC20 token to the list of supported tokens on the Butteryswap protocol.
     * @dev this function is payable and requires caller to pay ETH when calling, the amount of ETH to be sent is stored in the private variable "s_listingFee".
     */
    function addToken(address ERC20TokenAddress) external view payable nonReentrant{
        //checks
        //check address is valid.
        //check address dont already exists
        //check token health status.
        //effects
        //update supported tokens array
        //update mappings
        //emit events
        //interactions
    }

    // public
    // internal
    // private
    // internal & private view & pure functions

    ////////////////////////////////////////////////
    /// External & Public View & Pure Functions ///
    //////////////////////////////////////////////

    /// @notice This function returns the array of supported tokens.
    function getSupportedTokens() external view returns (address[] memory) {
        return s_supportedTokens;
    }

    /**
     * @todo store a list of supported memecoins
     * store the associated fee addresses to the listed memecoin
     * have functions to update the list of stored memcoin addresses
     * function to remove a specific memecoin address from the list
     * check memcoin health status
     * validate suported token addresses
     */
}
