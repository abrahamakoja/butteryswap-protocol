// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SupportedTokens
 * @author Abraham akoja
 * @notice This contract stores the list of supported ERC20 tokens for the ButterySwap protocol.
 * this contract handles the logic for adding new tokens, deleting listed tokens,validating and managing the healthFactor of all ERC20 tokens interacting with the Butteryswap protocol.
 */

// debug
// import {Script, console} from "forge-std/Script.sol";

////////////////
/// Imports ///
//////////////

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract SupportedTokens is ReentrancyGuard, Ownable {
    ///////////////
    /// Errors ///
    /////////////

    error SupportedTokens_CallerNotAdmin(address caller);
    error SupportedTokens_TokenAlreadyListed();
    error SupportedTokens_TokenAlreadyRequested();
    error SupportedTokens_InvalidTokenAddress();
    error SupportedTokens_TransferFailed(
        uint256 amountSent,
        uint256 expectedFee
    );
    error approveFailed(uint256 numOfRequest);
    error invalidToken(address token);
    // interfaces, libraries, contracts

    //////////////////////////
    /// Type Declarations ///
    ////////////////////////

    ////////////
    /// Enums ///
    ////////////

    /// @dev TokenState enum holding the different states possible for esch listed ERC-20 token.
    enum tokenState {
        UNLISTED,
        PENDING,
        APPROVED,
        DELISTED
    }

    /// @notice This struct stores the token request details.
    /// @dev This is only updated when the "requestTokenListing()" function is called.
    /// @param dev stores the address of the "requestTokenListing()" function caller.
    /// @param feeAddresess stores the whitelisted address to recieve fees on the listed token.
    /// @param timeListed stores the block.timestamp of the token when it was listed.
    struct tokenDetails {
        address tokenAddress;
        address dev;
        address feeAddress;
        uint256 timeListed;
        tokenState _tokenState;
    }

    ////////////////////////
    /// State variables ///
    //////////////////////

    /// @dev Array of addresses storing a list of supported tokens.
    address[] private s_listed;
    /// @dev Array of pending addresses awaiting approval.
    address[] private s_pendingTokenRequets;
    /// @dev Private variable of the listing fee to be paid by caller when calling "requestTokenListing()".
    uint256 constant LISTING_FEE = 1 ether;
    /// @dev Mapping of token address to token details struct.
    mapping(address tokenAddress => tokenDetails _tokenRequstDetails) private s_tokenDetails;
    /// @dev Maps a token address to it's index in the pending list .
    mapping(address tokenAddress => uint256 index) private s_pendingTokenIndex;
    /// @dev Mapping of token address to bool if requested
    mapping(address tokenAddress => bool requested) private s_islisted;
    /// @dev Mapping of listed tokens to bool isApproved
    mapping(address tokenAddress => bool approved) private s_isApproved;

    ///////////////
    /// Events ///
    /////////////

    event SupportedTokens_tokenListingRequestCreated(
        tokenDetails _tokenDetails,
        uint256 tokenIndex
    );
    event SupportedTokens_tokenListingRequestApproved(
        address approvedTokenAddress
    );


     ////////////////
    /// Modifier ///
    ///////////////

    modifier tokenIsActive(address token) {
        if( s_tokenDetails[token]._tokenState == tokenState.APPROVED){
            revert invalidToken(token);
        }
        _;
    }    
    modifier tokenIsListed(address token) {
        if ( s_islisted[token]) {
            revert SupportedTokens_TokenAlreadyListed();
        }
        _;
    }    

    //////////////////
    /// Functions ///
    ////////////////

    /// @notice contract constructor.
    constructor() Ownable(msg.sender) {}

    /// @notice receive function enables contract to recieve ETH.
    receive() external payable {}

    // fallback function (if exists)

    //////////////////////////
    ///External Functions ///
    ////////////////////////

    ///  @param ERC20TokenAddress: The ERC20 token address of the caller wishes to get listed.
    ///  @notice This function alllows caller to add an ERC20 token to the list of supported tokens on the Butteryswap protocol.
    ///  @dev this function is payable and requires caller to pay ETH when calling, the amount of ETH to be sent is stored in the private variable "s_listingFee".
    function requestTokenListing(
        address ERC20TokenAddress
    ) external payable nonReentrant tokenIsActive(ERC20TokenAddress){
        /// checks

        // check address is valid.
        if (ERC20TokenAddress == address(0)) {
            revert SupportedTokens_InvalidTokenAddress();
        }
        // check address dont already requested
        if ( s_tokenDetails[ERC20TokenAddress]._tokenState == tokenState.PENDING) {
            revert SupportedTokens_TokenAlreadyRequested();
        }
        // check if token is already approved
         if ( s_islisted[ERC20TokenAddress]) {
            revert SupportedTokens_TokenAlreadyListed();
        }

        /// effects
        /// @notice update tokenDetails struct.
        s_pendingTokenRequets.push(ERC20TokenAddress);
        tokenDetails memory _tokenDetails = tokenDetails({
            tokenAddress: ERC20TokenAddress,
            dev: msg.sender,
            feeAddress: msg.sender,
            timeListed: block.timestamp,
            _tokenState: tokenState.PENDING
        });

        s_tokenDetails[address(ERC20TokenAddress)] = _tokenDetails;
        s_pendingTokenIndex[address(ERC20TokenAddress)] = s_pendingTokenRequets
            .length;
        

        /// emit events
        emit SupportedTokens_tokenListingRequestCreated(
            _tokenDetails,
            s_pendingTokenIndex[address(ERC20TokenAddress)]
        );

        //interactions
        (bool success, ) = payable(msg.sender).call{value: LISTING_FEE}("");
        if (!success)
            revert SupportedTokens_TransferFailed(msg.value, LISTING_FEE);
    }

    /// @param index: The index position of the token request to approve.
    /// @notice This function alllows caller to approve specific token requests and adds the approved token address to the s_listed array.
    /// @dev onlyAdmin can call this function
    function approveTokenRequest(uint256 index) external onlyOwner {
        /// checks
        
        if (!(index < s_pendingTokenRequets.length)) {
            revert approveFailed(s_pendingTokenRequets.length);
        }

        /// Effects
        address token = s_pendingTokenRequets[index];
        s_listed.push(token);
        s_tokenDetails[token]._tokenState = tokenState.APPROVED;
        s_isApproved[token] = true;

        uint256 indexArray = s_pendingTokenRequets.length;
        uint256 indexToReplace = s_pendingTokenIndex[token] - 1;
        address lastToken = s_pendingTokenRequets[indexArray - 1];

        s_pendingTokenRequets[indexToReplace] = lastToken;
        s_pendingTokenIndex[lastToken] = indexToReplace + 1;

        // emit events
        emit SupportedTokens_tokenListingRequestApproved(address(token));

        // interactions

        // delete s_pendingTokenRequets[index];
        delete s_pendingTokenIndex[token];
        s_pendingTokenRequets.pop();
        //  console.log("requset length after :",s_pendingTokenRequets.length);
        //   console.log("request after index 1:",s_pendingTokenRequets[0]);

        // emit events
        // emit SupportedTokens_tokenListingRequestApproved(s_pendingTokenRequets[0],s_pendingTokenRequets[1],s_pendingTokenIndex[lastToken]);
    }

    /// @param token: The ERC20 token address of the caller wishes to remove.
    /// @notice This function alllows caller to remove an ERC20 token from the list of supported tokens on the Butteryswap protocol.
    /// @dev onlyAdmin can call this function.
    function delistToken(address token) external onlyOwner tokenIsListed(token) {
        s_tokenDetails[token]._tokenState = tokenState.DELISTED;
        s_isApproved[token] = false;
    }

    // public
    // internal
    // private
    // internal & private view & pure functions

    ////////////////////////////////////////////////
    /// External & Public View & Pure Functions ///
    //////////////////////////////////////////////

    /// @notice This function returns the array of supported tokens.
    function getTotalTokensListed() external view returns (address[] memory) {
        return s_listed;
    }

    /// @notice This function returns the array of pending token requests addresses.
    function getPendingTokens() external view returns (address[] memory) {
        return s_pendingTokenRequets;
    }

    /// @notice this function returns the index of a pending token request struct.
    function getTokenRequestDetails(
        address ERC20TokenAddress
    ) external view returns (tokenDetails memory _tokenDetails) {
        return s_tokenDetails[ERC20TokenAddress];
    }

    function checkTokenIslisted(address token) external view returns (bool) {
        // add check
       return  s_islisted[token];
    }

    function checkTokenIsApproved(address token) external view returns (bool) {
        if (!s_isApproved[token]) {
            revert invalidToken(token);
        }
        return s_isApproved[token];
    }
}
