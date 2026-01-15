// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title TokenManager
 * @author ButterySwap Protocol
 * @notice This contract stores the list of supported ERC20 tokens for the ButterySwap protocol.
 * this contract handles the logic for adding new tokens, deleting listed tokens,validating and managing the healthFactor of all ERC20 tokens interacting with the Butteryswap protocol.
 */

// debug this
/// @audit remove before production
import {Script, console2} from "forge-std/Script.sol";

/*//////////////////////////////////////////////////////////////
                                 IMPORT
    //////////////////////////////////////////////////////////////*/
import {IProtocolManager} from "./interfaces/IProtocolManager.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract TokenManager is
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardTransient
{
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error TokenManager__TokenIsListed();
    error TokenManager__TokenNotListed();
    error TokenManager__TokenAlreadyRequested();
    error TokenManager__InvalidTokenAddress();
    error TokenManager__InvalidTokenRequestID();
    error TokenManager__unauthorizedAccess();
    error TokenManager__invalidAmount();
    error TokenManager__TokenNotMarkedForUnListing();
    error TokenManager__noRequestAvailable();
    error TokenManager__TokenListingFailed();
    error TokenManager__LimitExceeded();
    error TokenManager__tokenNotOperational();

    /*//////////////////////////////////////////////////////////////
                                 ENUMS
    //////////////////////////////////////////////////////////////*/

    /// @dev this holds the different states of token listing status on the protocol.
    enum TokenListingState {
        NOT_LISTED,
        PENDING,
        LISTED
    }
    /// @dev this  holds the different state of listed tokens operational within the protocol.
    enum TokenOperationalState {
        NOT_ACTIVE,
        ACTIVE
    }

    /// @notice This struct stores the token request details data.
    /// @dev This is only updated when the "requestTokenListing" function is called.
    struct TokenDetials {
        address tokenAddress;
        address marketOwner;
        address feeAddress;
        ListingDetails listingDetails;
        TokenOperationalState _tokenOperationalState;
    }

    struct ListingDetails {
        uint256 timeListed;
        TokenListingState _tokenListingState;
    }

    struct RequestDetails {
        uint256 requestID;
        uint256 timeRequested;
        TokenDetials tokenDetails;
    }

    /*/////////////////                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                /////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant TOKEN_MANAGER_ADMIN =
        keccak256("TOKEN_MANAGER_ADMIN");

    IProtocolManager private protocolManager;
    uint256 public totalRequestedTokens;
    uint256 internal lastApproved;
    uint256 private totalListedTokens;
    uint256 private totalTokensToUnList;
    uint256 private totalUnListedTokens;

    mapping(uint256 requestID => TokenDetials details) internal tokenDetails;
    mapping(uint256 requestID => RequestDetails details)
        internal requestDetails;
    mapping(address token => uint256 tokenID) internal addressToTokenID;

    // remove the rest
    /// @dev Mapping of a specific token address to it's token details data.
    mapping(address tokenAddress => TokenDetials _tokenDetails)
        private s_tokenDetails;

    /// @dev Mapping of token address to a boolean, checks if a token has been listed and returns a boolean corresponding with the state , true if yes, false if no.
    mapping(address tokenAddress => bool listed) private s_isListed;
    mapping(uint256 index => address tokenAddress)
        private s_requestedTokenIndexToAddress;
    mapping(address tokenAddress => uint index) private s_requestedTokenToIndex;
    mapping(address tokenAddress => uint index) private s_listedTokenToIndex;
    mapping(uint256 index => address tokenAddress)
        private s_listedTokenIndexToAddress;
    mapping(uint256 index => address tokenAddress)
        private s_tokenToUnListIndexToAddress;
    mapping(address tokenAddress => uint256 index)
        private s_tokenToUnListAddressToIndex;
    mapping(address tokenAddress => bool listed) private s_toUnList;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event tokenListingRequestCreated(
        address indexed token,
        uint256 indexed requestID
    );
    event tokenListed(address indexed token, uint256 indexed tokenID);
    event tokenUnListingRequested(address indexed deListedTokenAddress);
    event tokenUnListed(address indexed token, uint256 timeUnlisted);
    event tokenFeeAddressUpdated(
        address indexed token,
        address indexed oldFeeAddress,
        address indexed newFeeAddress
    );

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier isValidAddress(address token) {
        require((token != address(0)), TokenManager__InvalidTokenAddress());
        _;
    }

    /// @dev isTokenOperational modifier ensures token state is active else it reverts with the error invalidToken
    modifier isTokenOperational(address token) {
        require(
            _checkTokenIsOperational(token) == TokenOperationalState.NOT_ACTIVE,
            TokenManager__tokenNotOperational()
        );

        _;
    }

    /// @dev isTokenListed modifier ensures token is listed else it reverts with the error SupportedTokens_TokenAlreadyListed
    modifier isTokenListed(address token) {
        require(
            _checkTokenIsListed(token) != TokenListingState.LISTED,
            TokenManager__TokenIsListed()
        );
        _;
    }
    modifier isTokenRequested(address token) {
        require(
            _checkTokenIsRequested(token) != true,
            TokenManager__TokenAlreadyRequested()
        );
        _;
    }

    function _checkTokenIsListed(
        address token
    ) internal view returns (TokenListingState state) {
        uint256 tokenID = addressToTokenID[token];
        TokenDetials memory details = tokenDetails[tokenID];
        return details.listingDetails._tokenListingState;
    }
    function _checkTokenIsOperational(
        address token
    ) internal view returns (TokenOperationalState state) {
        uint256 tokenID = addressToTokenID[token];
        TokenDetials memory details = tokenDetails[tokenID];
        return details._tokenOperationalState;
    }
    function _checkTokenIsRequested(
        address token
    ) internal view returns (bool requested) {
        uint256 tokenID = addressToTokenID[token];
        RequestDetails memory details = requestDetails[tokenID];
        uint256 ID = details.requestID;
        if (ID == 0) {
            return false;
        } else {
            return true;
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice contract constructor.
    function initialize(address _protocolManager) public initializer {
        __AccessControl_init();
        protocolManager = IProtocolManager(_protocolManager);

        _grantRole(
            DEFAULT_ADMIN_ROLE,
            IProtocolManager(_protocolManager).deployer()
        );
        _grantRole(
            TOKEN_MANAGER_ADMIN,
            IProtocolManager(_protocolManager).deployer()
        );

        // updateTokenManagerContract
        protocolManager.updateTokenManagerContract(address(this), msg.sender);

        // storage variables
        totalRequestedTokens = 0;
        totalListedTokens = 0;
        lastApproved = 0;
        totalTokensToUnList = 0;
        totalUnListedTokens = 0;
    }
    function _authorizeUpgrade(
        address
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
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
        returns (uint256 requestID)
    {
        // checks
        require(msg.value != 0, TokenManager__invalidAmount());
        require(
            msg.value == protocolManager.calculateTokenListingFee(token),
            TokenManager__invalidAmount()
        );
        /// effects
        totalRequestedTokens++;
        requestID = totalRequestedTokens;

        //  listing details
        ListingDetails memory details;

        details._tokenListingState = TokenListingState.PENDING;

        /// @notice update TokenDetials struct.
        TokenDetials memory _tokenDetails = TokenDetials({
            tokenAddress: token,
            marketOwner: msg.sender,
            feeAddress: msg.sender,
            listingDetails: details,
            _tokenOperationalState: TokenOperationalState.NOT_ACTIVE
        });
        // request details
        RequestDetails memory _requestDetails = RequestDetails({
            requestID: requestID,
            timeRequested: block.timestamp,
            tokenDetails: _tokenDetails
        });

        requestDetails[requestID] = _requestDetails;

        /// emit events
        emit tokenListingRequestCreated({token: token, requestID: requestID});

        //interactions
        /// @dev initiate the fee payment
        (bool success, ) = protocolManager.FEE_CONTRACT().call{
            value: msg.value
        }("");
        require(success, TokenManager__TokenListingFailed());
        return requestID;
    }

    function updateTokenFeeAddress(
        address token,
        address newFeeAddress
    )
        external
        payable
        isValidAddress(token)
        isValidAddress(newFeeAddress)
        isTokenListed(token)
        isTokenOperational(token)
        nonReentrant
    {
        require(msg.value != 0, TokenManager__invalidAmount());
        require(
            msg.value ==
                protocolManager.calculateTokenFeeAddressUpdateFee(token),
            TokenManager__invalidAmount()
        );

        uint256 tokenID = addressToTokenID[token];
        TokenDetials storage details = tokenDetails[tokenID];
        require(
            msg.sender == details.marketOwner,
            TokenManager__unauthorizedAccess()
        );

        // effects
        address oldFeeAddress = details.feeAddress;
        details.feeAddress = newFeeAddress;

        emit tokenFeeAddressUpdated({
            token: token,
            oldFeeAddress: oldFeeAddress,
            newFeeAddress: newFeeAddress
        });

        /// @dev initiate the fee payment
        (bool success, ) = protocolManager.FEE_CONTRACT().call{
            value: msg.value
        }("");
        if (!success) revert TokenManager__TokenListingFailed();
    }

    /// @notice This function allows an admin to approve specific token requests and adds the approved token address to the s_listed array.
    /// @dev onlyAdmin can call this function
    function approveTokenRequest(
        uint256 requestID
    ) external nonReentrant onlyRole(TOKEN_MANAGER_ADMIN) {
        require(totalRequestedTokens != 0, TokenManager__noRequestAvailable());

        require(requestID != 0, TokenManager__InvalidTokenRequestID());

        /// Effects
        totalListedTokens++;

        uint256 tokenID = totalListedTokens;
        RequestDetails storage details = requestDetails[requestID];
        address token = details.tokenDetails.tokenAddress;

        details.tokenDetails.listingDetails.timeListed = block.timestamp;
        details
            .tokenDetails
            .listingDetails
            ._tokenListingState = TokenListingState.LISTED;

        details.tokenDetails._tokenOperationalState = TokenOperationalState
            .ACTIVE;

        TokenDetials memory _tokenDetails = details.tokenDetails;

        lastApproved = requestID;

        tokenDetails[tokenID] = _tokenDetails;

        // emit
        emit tokenListed({token: token, tokenID: tokenID});
    }

    function unListToken(
        address token
    ) external isValidAddress(token) onlyRole(TOKEN_MANAGER_ADMIN) {
        // @audit suspend asset from protocol
        uint256 tokenID = addressToTokenID[token];

        TokenDetials storage details = tokenDetails[tokenID];
        details._tokenOperationalState = TokenOperationalState.NOT_ACTIVE;
        details.listingDetails._tokenListingState = TokenListingState
            .NOT_LISTED;

        totalUnListedTokens++;

        emit tokenUnListed({token: token, timeUnlisted: block.timestamp});
    }

    ////////////////////////////////////////////////
    /// External & Public View & Pure Functions ///
    //////////////////////////////////////////////

    /// @notice This function returns the array of supported tokens.
    function getTotalListedActiveTokens()
        external
        view
        nonReentrantView
        returns (address[] memory activeTokens)
    {
        uint256 activeTokenCount = 0;
        uint256 count = totalListedTokens;
        address[] memory tokens = new address[](count);

        for (uint256 index = 0; index < count; index++) {
            TokenDetials storage details = tokenDetails[index];
            if (
                details.listingDetails._tokenListingState ==
                TokenListingState.LISTED
            ) {
                tokens[activeTokenCount] = details.tokenAddress;
                activeTokenCount++;
            }
            continue;
        }

        activeTokens = new address[](activeTokenCount);
        for (uint256 index = 0; index < activeTokenCount; index++) {
            activeTokens[index] = tokens[index];
        }
        return activeTokens;
    }

    /// @notice This function returns the array of pending token requests addresses.
    function getAllRequestedTokenID()
        external
        view
        onlyRole(TOKEN_MANAGER_ADMIN)
        returns (uint256[] memory requestID)
    {
        uint256 requestDelta = _PendingRequests();
        uint256 index = lastApproved;
        console2.log("lastApproved", lastApproved);
        index = index + 1;
        requestID = new uint256[](requestDelta);
        console2.log("index", index);
        for (uint256 i = 0; i < requestDelta; i++) {
            console2.log("i", i, "index", index);
            RequestDetails storage details = requestDetails[index];
            requestID[i] = details.requestID;
            index++;
        }
        return requestID;
    }

    /// @notice this function returns the struct details of a token.
    function getTokenDetails(
        address token
    )
        external
        view
        returns (
            address tokenAddress,
            address marketOwner,
            address feeAddress,
            uint256 timeListed,
            uint8 listingState,
            uint8 operationalState
        )
    {
        uint256 tokenID = addressToTokenID[token];
        TokenDetials storage details = tokenDetails[tokenID];

        return (
            details.tokenAddress,
            details.marketOwner,
            details.feeAddress,
            details.listingDetails.timeListed,
            uint8(details.listingDetails._tokenListingState),
            uint8(details._tokenOperationalState)
        );
    }

    function checkIsTokenListed(
        address token
    ) external view isValidAddress(token) returns (bool isListed) {
        TokenListingState state = _checkTokenIsListed(token);

        if (state == TokenListingState.LISTED) {
            isListed = true;
        } else {
            isListed = false;
        }
        return isListed;
    }

    function getTotalTokenRequestCount()
        external
        view
        returns (uint256 totalRequestCount)
    {
        return totalRequestedTokens;
    }
    function getTotalPendingRequests()
        external
        view
        returns (uint256 totalPendingRequests)
    {
        totalPendingRequests = _PendingRequests();
        return totalPendingRequests;
    }
    function _PendingRequests() internal view returns (uint256) {
        return totalRequestedTokens - lastApproved;
    }

    function checkIsTokenOperational(
        address token
    ) external view isValidAddress(token) returns (bool operational) {
        TokenOperationalState state = _checkTokenIsOperational(token);
        if (state == TokenOperationalState.ACTIVE) {
            operational = true;
        } else {
            operational = false;
        }
        return operational;
    }

    // @audit this goes to oracle/fix calculation
    function getTotalTokenEthValue(
        address token,
        uint256 amount
    ) public view returns (uint256 tokenEthValue) {
        // verify token is supported

        tokenEthValue = 1e18;
        return tokenEthValue;
    }
}
