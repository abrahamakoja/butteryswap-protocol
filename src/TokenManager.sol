// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title TokenManager
 * @author ButterySwap Protocol
 * @notice This contract stores the list of supported ERC20 tokens for the ButterySwap protocol.
 * this contract handles the logic for adding new tokens, deleting listed tokens,validating and managing the healthFactor of all ERC20 tokens interacting with the Butteryswap protocol.
 */

// debug
/// @audit remove before production
// import {Script, console} from "forge-std/Script.sol";

/*//////////////////////////////////////////////////////////////
                                 IMPORT
    //////////////////////////////////////////////////////////////*/

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IProtocolManager} from "./interfaces/IProtocolManager.sol";

contract TokenManager is ReentrancyGuard, Ownable {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error SupportedTokens__CallerNotAdmin(address caller);
    error SupportedTokens__isTokenListed();
    error TokenManager__TokenAlreadyRequested();
    error TokenManager__InvalidTokenAddress();
    error SupportedTokens__invalidAddress();
    error SupportedTokens__TransferFailed(
        uint256 amountSent,
        uint256 expectedFee
    );
    error SupportedTokens__approveFailed();
    error SupportedTokens__approveLimitExceeded(uint256 numOfRequest);
    error SupportedTokens__invalidToken(address token);
    error SupportedTokens__inActiveToken(address token);

    /*//////////////////////////////////////////////////////////////
                                 ENUMS
    //////////////////////////////////////////////////////////////*/

    /// @dev this holds the different states of token listing status on the protocol.
    enum tokenListingState {
        NOT_LISTED,
        PENDING,
        LISTED
    }
    /// @dev this  holds the different state of listed tokens operational within the protocol.
    enum tokenOperationalState {
        NOT_ACTIVE,
        ACTIVE
    }

    /// @notice This struct stores the token request details data.
    /// @dev This is only updated when the "requestTokenListing" function is called.
    /// @param tokenAddress stores the address of token to be listed.
    /// @param marketOwner stores the address of user listing the token.
    /// @param feeAddress stores the whitelisted address to receive fees on the listed token.
    /// @param timeListed stores the block.timestamp of the token when it was listed.
    /// @param _tokenOperationalState stores the state of the operational state of the token.
    struct tokenDetails {
        address tokenAddress;
        address marketOwner;
        address feeAddress;
        uint256 timeListed;
        tokenListingState _tokenListingState;
        tokenOperationalState _tokenOperationalState;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    IProtocolManager private immutable protocolManager;
    /// @dev Array of addresses storing a list of listed tokens.
    address[] public s_listed;
    /// @dev Array of addresses awaiting approval.
    address[] public s_pendingTokenRequests;
    /// @dev listing fee to be paid by caller when creating a listing request.
    uint256 constant LISTING_FEE = 1 ether;
    /// @dev Mapping of a specific token address to it's token details data.
    mapping(address tokenAddress => tokenDetails _tokenDetails)
        private s_tokenDetails;
    /// @dev Maps a token address to it's index in the pending list .
    mapping(address tokenAddress => uint256 index) public s_pendingTokenIndex;
    /// @dev Maps a token index to it's address in the pending list .
    mapping(uint256 index => address tokenAddress)
        public s_pendingTokenIndexToAddress;
    /// @dev Mapping of token address to a boolean, checks if a token has been listed and returns a boolean corresponding with the state , true if yes, false if no.
    mapping(address tokenAddress => bool listed) public s_isListed;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event SupportedTokens_tokenListingRequestCreated(
        tokenDetails _tokenDetails,
        uint256 tokenIndex
    );
    event SupportedTokens_tokenListingRequestApproved(
        address approvedTokenAddress
    );

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier isValidAddress(address val) {
        if (val == address(0)) revert TokenManager__InvalidTokenAddress();
        _;
    }

    /// @dev isTokenActive modifier ensures token state is active else it reverts with the error invalidToken
    modifier isTokenActive(address token) {
        if (
            s_tokenDetails[token]._tokenOperationalState ==
            tokenOperationalState.ACTIVE
        ) {
            revert SupportedTokens__inActiveToken(token);
        }
        _;
    }

    /// @dev isTokenListed modifier ensures token is listed else it reverts with the error SupportedTokens_TokenAlreadyListed
    modifier isTokenListed(address token) {
        if (
            s_tokenDetails[token]._tokenListingState ==
            tokenListingState.LISTED &&
            s_isListed[token]
        ) {
            revert SupportedTokens__isTokenListed();
        }
        _;
    }
    modifier isTokenRequested(address token) {
        if (
            s_tokenDetails[token]._tokenListingState ==
            tokenListingState.PENDING
        ) {
            revert TokenManager__TokenAlreadyRequested();
        }
        _;
    }

    /// @notice contract constructor.
    constructor(address _protocolManager) Ownable(msg.sender) {
        protocolManager = IProtocolManager(_protocolManager);
    }

    /// @notice receive function enables contract to receive ETH.
    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    ///  @param token  The ERC20 token address of the caller wishes to get listed.
    ///  @notice This function allows caller to add an ERC20 token to the list of supported tokens on the Butteryswap protocol.
    ///  @dev this function is payable and requires caller to pay ETH when calling, the amount of ETH to be sent is stored in the private variable "s_listingFee".
    function requestTokenListing(
        address token
    )
        external
        payable
        isValidAddress(token)
        isTokenListed(token)
        isTokenRequested(token)
        nonReentrant
    {
        /// checks

        if (
            s_tokenDetails[token]._tokenListingState !=
            tokenListingState.NOT_LISTED
        ) {
            revert TokenManager__TokenAlreadyRequested();
        }

        /// effects
        /// @notice updates the s_pendingTokenRequests array
        s_pendingTokenRequests.push(token);

        /// @notice update tokenDetails struct.
        tokenDetails memory _tokenDetails = tokenDetails({
            tokenAddress: token,
            marketOwner: msg.sender,
            feeAddress: msg.sender,
            timeListed: block.timestamp,
            _tokenListingState: tokenListingState.PENDING,
            _tokenOperationalState: tokenOperationalState.NOT_ACTIVE
        });

        ///  @dev update the details mapping
        s_tokenDetails[address(token)] = _tokenDetails;
        /// @dev maps the token address to it's index on the que
        s_pendingTokenIndex[address(token)] = s_pendingTokenRequests
            .length;
        s_pendingTokenIndexToAddress[s_pendingTokenRequests.length] = address(
            token
        );
        /// emit events
        emit SupportedTokens_tokenListingRequestCreated(
            _tokenDetails,
            s_pendingTokenIndex[address(token)]
        );

        //interactions
        /// @dev initiate the fee payment
        (bool success, ) = payable(msg.sender).call{value: LISTING_FEE}("");
        if (!success)
            revert SupportedTokens__TransferFailed(msg.value, LISTING_FEE);
    }

    /// @param index: The index position of the token request to approve.
    /// @notice This function allows an admin to approve specific token requests and adds the approved token address to the s_listed array.
    /// @dev onlyAdmin can call this function
    function approveTokenRequest(uint256 index) external onlyOwner {
        /// checks

        if (index > s_pendingTokenRequests.length) {
            revert SupportedTokens__approveLimitExceeded(
                s_pendingTokenRequests.length
            );
        }
        if (s_pendingTokenRequests.length <= 0) {
            revert SupportedTokens__approveFailed();
        }

        /// Effects
        /// @dev get the address of the token attached to the inputted index
        address token = s_pendingTokenRequests[index];
        /// @dev update token listing detail
        s_tokenDetails[token]._tokenListingState = tokenListingState.LISTED;
        /// @dev update token operational detail
        s_tokenDetails[token]._tokenOperationalState = tokenOperationalState
            .ACTIVE;
        /// @dev update s_isListed mapping to true
        s_isListed[token] = true;
        /// @dev update s_listed array
        s_listed.push(token);

        /// @notice remove token from s_pendingTokenRequests array

        /// @dev get the total count of request
        uint256 requestCount = s_pendingTokenRequests.length;
        /// @dev get the previous index of the token to be removed from the s_pendingTokenRequests array
        uint256 previousIndex = s_pendingTokenIndex[token] - 1;
        /// @dev get the last requested token in the s_pendingTokenRequests array
        address lastRequestedToken = s_pendingTokenRequests[requestCount - 1];

        /// @dev swaps the previous index position to that of the last requested token
        s_pendingTokenRequests[previousIndex] = lastRequestedToken;
        /// @dev replace the current index position mapping of the token with the last requested token in the s_pendingTokenRequests array
        s_pendingTokenIndex[lastRequestedToken] = previousIndex + 1;

        // emit
        emit SupportedTokens_tokenListingRequestApproved(address(token));

        // interactions

        // delete s_pendingTokenRequests[index];
        delete s_pendingTokenIndex[token];
        s_pendingTokenRequests.pop();
    }

    function delistToken() external {}

    /// @param token: The ERC20 token address of the caller wishes to remove.
    /// @notice This function allows admin to remove an ERC20 token from the list of supported tokens on the Butteryswap protocol.
    /// @dev onlyAdmin can call this function.
    function emergencyDeListToken(
        address token
    ) external onlyOwner isTokenListed(token) {
        s_isListed[token] = false;
        s_tokenDetails[token]._tokenListingState = tokenListingState.NOT_LISTED;
        s_tokenDetails[token]._tokenOperationalState = tokenOperationalState
            .NOT_ACTIVE;
    }

    ////////////////////////////////////////////////
    /// External & Public View & Pure Functions ///
    //////////////////////////////////////////////

    /// @notice This function returns the array of supported tokens.
    function getTotalListedActiveTokens()
        external
        view
        returns (address[] memory)
    {
        uint256 activeTokens;
        address[] memory Tokenaddresses = new address[](s_listed.length);
        for (uint256 index = 0; index < s_listed.length; index++) {
            if (
                s_tokenDetails[s_listed[index]]._tokenOperationalState ==
                tokenOperationalState.ACTIVE
            ) {
                Tokenaddresses[activeTokens] = address(s_listed[index]);
                activeTokens++;
            }
            continue;
        }
        address[] memory activeTokenaddresses = new address[](activeTokens);
        for (uint256 index = 0; index < activeTokens; index++) {
            activeTokenaddresses[index] = Tokenaddresses[index];
        }
        return activeTokenaddresses;
    }

    /// @notice This function returns the array of pending token requests addresses.
    function getPendingTokens() external view returns (address[] memory) {
        return s_pendingTokenRequests;
    }

    /// @notice this function returns the struct details of a token.
    function getTokenDetails(
        address token
    ) external view returns (tokenDetails memory _tokenDetails) {
        return s_tokenDetails[token];
    }

    function checkisTokenListed(
        address token
    ) external view isValidAddress(token) returns (bool isListed) {
        if (
            s_tokenDetails[token]._tokenListingState ==
            tokenListingState.LISTED &&
            s_isListed[token]
        ) {
            return isListed = true;
        }
        return isListed = false;
    }
}
