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
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IProtocolManager} from "./interfaces/IProtocolManager.sol";

contract TokenManager is ReentrancyGuard, AccessControl {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error SupportedTokens__CallerNotAdmin(address caller);
    error TokenManager__TokenIsListed();
    error TokenManager__TokenNotListed();
    error TokenManager__TokenAlreadyRequested();
    error TokenManager__InvalidTokenAddress();
    error SupportedTokens__invalidAddress();
    error TokenManager__unauthorizedAccess();
    error TokenManager__invalidAmount();
    error TokenManager__noRequestAvailable();
    error TokenManager__TokenListingFailed(uint256 amountSent);
    error SupportedTokens__approveFailed();
    error TokenManager__LimitExceeded();
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

    bytes32 public constant TOKENMANAGER_ADMIN =
        keccak256("TOKENMANAGER_ADMIN");

    IProtocolManager private immutable protocolManager;
    uint256 private totalRequestedTokens;
    uint256 private totalListedTokens;
    /// @dev Array of addresses storing a list of listed tokens.
    address[] public s_listed;
    /// @dev Array of addresses awaiting approval.
    // address[] public s_pendingTokenRequests;

    /// @dev Mapping of a specific token address to it's token details data.
    mapping(address tokenAddress => tokenDetails _tokenDetails)
        private s_tokenDetails;
    /// @dev Maps a token address to it's index in the pending list .
    // mapping(address tokenAddress => uint256 index) public s_pendingTokenIndex;
    /// @dev Maps a token index to it's address in the pending list .
    mapping(uint256 index => address tokenAddress)
        private s_pendingTokenIndexToAddress;
    /// @dev Mapping of token address to a boolean, checks if a token has been listed and returns a boolean corresponding with the state , true if yes, false if no.
    mapping(address tokenAddress => bool listed) private s_isListed;
    mapping(address tokenAddress => uint index) private s_requestedTokenToIndex;
    mapping(address tokenAddress => uint index) private s_listedTokenToIndex;
     mapping(uint256 index => address tokenAddress)
        private s_listedTokenIndexToAddress;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event tokenListingRequestCreated(
        tokenDetails indexed _tokenDetails,
        uint256 indexed tokenIndex
    );
    event tokenListingRequestApproved(address indexed approvedTokenAddress);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyTokenManagerAdmin() {
        if (!hasRole(TOKENMANAGER_ADMIN, msg.sender))
            revert TokenManager__unauthorizedAccess();
        _;
    }

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
            revert TokenManager__TokenIsListed();
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
    constructor(address _protocolManager) {
        protocolManager = IProtocolManager(_protocolManager);
        bool success = _grantRole(
            TOKENMANAGER_ADMIN,
            IProtocolManager(_protocolManager).TOKENMANAGER_ADMIN()
        );
        if (!success) revert();
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
        if (msg.value == 0) revert TokenManager__invalidAmount();
        if (msg.value != protocolManager.LISTING_FEE())
            revert TokenManager__invalidAmount();

        /// effects
        uint256 _totalRequestedTokens = totalRequestedTokens;
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
        s_requestedTokenToIndex[address(token)] = _totalRequestedTokens;
        s_pendingTokenIndexToAddress[_totalRequestedTokens] = address(token);
        s_isListed[address(token)] = false;
        totalRequestedTokens++;
        /// emit events
        emit tokenListingRequestCreated(
            _tokenDetails,
            s_requestedTokenToIndex[address(token)]
        );

        //interactions
        /// @dev initiate the fee payment
        (bool success, ) = protocolManager.FEE_CONTRACT().call{value: msg.value}("");
        if (!success) revert TokenManager__TokenListingFailed(msg.value);
    }

    /// @param index: The index position of the token request to approve.
    /// @notice This function allows an admin to approve specific token requests and adds the approved token address to the s_listed array.
    /// @dev onlyAdmin can call this function
    function approveTokenRequest(uint256 index) external onlyTokenManagerAdmin {
        /// checks

        if (totalRequestedTokens == 0) {
            revert TokenManager__noRequestAvailable();
        }
        if (index > totalRequestedTokens) {
            revert TokenManager__LimitExceeded();
        }

        /// Effects
        /// @dev get the address of the token attached to the inputted index
        address token = s_pendingTokenIndexToAddress[index];
        if (
            s_tokenDetails[token]._tokenListingState ==
            tokenListingState.LISTED &&
            s_isListed[token]
        ) {
            revert TokenManager__TokenIsListed();
        }
        uint256 _totalListedTokens = totalListedTokens;

        /// @dev update token listing detail
        s_tokenDetails[token]._tokenListingState = tokenListingState.LISTED;
        /// @dev update token operational detail
        s_tokenDetails[token]._tokenOperationalState = tokenOperationalState
            .ACTIVE;
            s_listedTokenToIndex[token] = _totalListedTokens;
            s_listedTokenIndexToAddress[_totalListedTokens] = address(token);
        /// @dev update s_isListed mapping to true
        s_isListed[token] = true;

        delete s_pendingTokenIndexToAddress[index];
        delete s_requestedTokenToIndex[token];
        totalRequestedTokens--;
        totalListedTokens++;


        // emit
        emit tokenListingRequestApproved(address(token));
    }

    function delistToken(
        address token
    ) external isValidAddress(token) onlyTokenManagerAdmin {
        if (
            s_tokenDetails[token]._tokenListingState ==
            tokenListingState.NOT_LISTED &&
            s_tokenDetails[token]._tokenOperationalState ==
            tokenOperationalState.NOT_ACTIVE &&
            !s_isListed[token]
        ) {
            revert TokenManager__TokenNotListed();
        }
        uint256 index = s_listedTokenToIndex[token];

        s_isListed[token] = false;
      delete  s_tokenDetails[token];
     delete s_listedTokenToIndex[token];
    delete s_listedTokenIndexToAddress[index];
    totalListedTokens--;
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
