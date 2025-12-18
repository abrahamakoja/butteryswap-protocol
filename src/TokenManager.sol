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
    error TokenManager__unauthorizedAccess();
    error TokenManager__invalidAmount();
    error TokenManager__TokenNotMarkedForUnListing();
    error TokenManager__noRequestAvailable();
    error TokenManager__TokenListingFailed(uint256 amountSent);
    error TokenManager__LimitExceeded();
    error TokenManager__tokenNotOperational(address token);

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

    /*/////////////////                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                /////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public TOKEN_MANAGER_ADMIN;

    IProtocolManager private protocolManager;
    uint256 public totalRequestedTokens;
    uint256 private totalListedTokens;
    uint256 private totalTokensToUnList;
    uint256 private totalUnListedTokens;

    /// @dev Mapping of a specific token address to it's token details data.
    mapping(address tokenAddress => tokenDetails _tokenDetails)
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
        address indexed tokenAddress,
        uint256 indexed tokenIndex
    );
    event tokenListed(address indexed listedTokenAddress);
    event tokenUnListingRequested(address indexed deListedTokenAddress);
    event tokenUnListed(address indexed deListedTokenAddress);
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
        if (
            s_tokenDetails[token]._tokenOperationalState ==
            tokenOperationalState.ACTIVE
        ) {
            revert TokenManager__tokenNotOperational(token);
        }
        _;
    }

    /// @dev isTokenListed modifier ensures token is listed else it reverts with the error SupportedTokens_TokenAlreadyListed
    modifier isTokenListed(address token) {
        if (
            s_tokenDetails[token]._tokenListingState ==
            tokenListingState.LISTED &&
            !(s_isListed[token])
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

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice contract constructor.
    function initialize(address _protocolManager) public initializer {
        __AccessControl_init();
        protocolManager = IProtocolManager(_protocolManager);

        TOKEN_MANAGER_ADMIN = keccak256("TOKEN_MANAGER_ADMIN");

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
    {
        if (msg.value == 0) revert TokenManager__invalidAmount();
        if (
            msg.value < protocolManager.calculateTokenListingFee(address(token))
        ) revert TokenManager__invalidAmount();

        /// effects
        uint256 _totalRequestedTokens = totalRequestedTokens;
        uint256 index = _totalRequestedTokens +
            protocolManager.INDEX_PRECISION();
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
        s_requestedTokenToIndex[address(token)] = index;
        console2.log("request index:", index);
        s_requestedTokenIndexToAddress[index] = address(token);
        s_isListed[address(token)] = false;
        totalRequestedTokens++;
        /// emit events
        emit tokenListingRequestCreated(
            address(token),
            s_requestedTokenToIndex[address(token)]
        );

        //interactions
        /// @dev initiate the fee payment
        (bool success, ) = protocolManager.FEE_CONTRACT().call{
            value: msg.value
        }("");
        if (!success) revert TokenManager__TokenListingFailed(msg.value);
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
    {
        if (msg.value == 0) revert TokenManager__invalidAmount();
        if (
            msg.value < protocolManager.calculateTokenFeeAddressUpdateFee(token)
        ) revert TokenManager__invalidAmount();

        if (s_tokenDetails[address(token)].marketOwner != address(msg.sender))
            revert TokenManager__unauthorizedAccess();
        address oldFeeAddress = s_tokenDetails[address(token)].feeAddress;
        s_tokenDetails[address(token)].feeAddress = newFeeAddress;

        emit tokenFeeAddressUpdated(
            address(token),
            address(oldFeeAddress),
            address(newFeeAddress)
        );
        /// @dev initiate the fee payment
        (bool success, ) = protocolManager.FEE_CONTRACT().call{
            value: msg.value
        }("");
        if (!success) revert TokenManager__TokenListingFailed(msg.value);
    }

    /// @param index: The index position of the token request to approve.
    /// @notice This function allows an admin to approve specific token requests and adds the approved token address to the s_listed array.
    /// @dev onlyAdmin can call this function
    function approveTokenRequest(
        uint256 index
    ) external onlyRole(TOKEN_MANAGER_ADMIN) {
        /// checks

        if (totalRequestedTokens == 0) {
            revert TokenManager__noRequestAvailable();
        }
        if (index > totalRequestedTokens) {
            revert TokenManager__LimitExceeded();
        }
        console2.log("index ::", index);

        /// Effects
        /// @dev get the address of the token attached to the inputted index
        address token = s_requestedTokenIndexToAddress[index];
        console2.log("index token::", index, token);
        if (
            s_tokenDetails[token]._tokenListingState ==
            tokenListingState.LISTED &&
            s_isListed[token]
        ) {
            revert TokenManager__TokenIsListed();
        }
        uint256 _totalListedTokens = totalListedTokens;
        // console2.log("index _totalListedTokens before::", _totalListedTokens);
        uint256 newIndex = _totalListedTokens +
            protocolManager.INDEX_PRECISION();

        console2.log("index newIndex ::", newIndex);
        /// @dev update token listing detail
        s_tokenDetails[token]._tokenListingState = tokenListingState.LISTED;
        // /// @dev update token operational detail
        s_tokenDetails[token]._tokenOperationalState = tokenOperationalState
            .ACTIVE;
        s_listedTokenToIndex[token] = newIndex;
        s_listedTokenIndexToAddress[newIndex] = address(token);
        // /// @dev update s_isListed mapping to true
        s_isListed[token] = true;

        totalListedTokens += 1;
        console2.log("index totalListedTokens ::", totalListedTokens);
        delete s_requestedTokenIndexToAddress[index];
        delete s_requestedTokenToIndex[token];
        console2.log("index totalRequestedTokens ::", totalRequestedTokens);

        // emit
        emit tokenListed(address(token));
    }

    function unListToken(
        address token
    )
        external
        payable
        isValidAddress(token)
        isTokenListed(token)
        isTokenOperational(token)
    {
        if (msg.value == 0) revert TokenManager__invalidAmount();
        if (msg.value != protocolManager.calculateTokenUnListingFee(token))
            revert TokenManager__invalidAmount();
        if (s_tokenDetails[address(token)].marketOwner != address(msg.sender))
            revert TokenManager__unauthorizedAccess();
        if (
            s_tokenDetails[token]._tokenListingState ==
            tokenListingState.NOT_LISTED &&
            s_tokenDetails[token]._tokenOperationalState ==
            tokenOperationalState.NOT_ACTIVE &&
            !s_isListed[token]
        ) {
            revert TokenManager__TokenNotListed();
        }
        uint256 _totalTokensToUnList = totalTokensToUnList;
        uint256 index = _totalTokensToUnList +
            protocolManager.INDEX_PRECISION();
        s_tokenToUnListIndexToAddress[index] = address(token);
        s_tokenToUnListAddressToIndex[address(token)] = index;
        s_toUnList[address(token)] = true;
        totalTokensToUnList++;

        emit tokenUnListingRequested(address(token));

        // pay fee
        (bool success, ) = protocolManager.FEE_CONTRACT().call{
            value: msg.value
        }("");
        if (!success) revert TokenManager__TokenListingFailed(msg.value);
    }
    function emergencyUnListToken(
        address token
    ) external isValidAddress(token) onlyRole(TOKEN_MANAGER_ADMIN) {
        if (
            s_tokenDetails[token]._tokenListingState ==
            tokenListingState.NOT_LISTED &&
            s_tokenDetails[token]._tokenOperationalState ==
            tokenOperationalState.NOT_ACTIVE &&
            !s_isListed[token]
        ) revert TokenManager__TokenNotListed();
        if (s_toUnList[address(token)] != true)
            revert TokenManager__TokenNotMarkedForUnListing();
        uint256 index = s_tokenToUnListAddressToIndex[token];

        s_isListed[token] = false;
        delete s_tokenDetails[token];
        delete s_listedTokenToIndex[token];
        delete s_listedTokenIndexToAddress[index];
        delete s_tokenToUnListIndexToAddress[index];
        delete s_tokenToUnListAddressToIndex[address(token)];
        totalListedTokens--;
        totalTokensToUnList--;
        totalUnListedTokens++;

        emit tokenUnListed(address(token));
    }

    ////////////////////////////////////////////////
    /// External & Public View & Pure Functions ///
    //////////////////////////////////////////////

    /// @notice This function returns the array of supported tokens.
    function getTotalListedActiveTokens()
        external
        view
        returns (address[] memory activeTokens)
    {
        uint256 activeTokenCount;
        address[] memory token = new address[](totalListedTokens);
        for (uint256 index = 0; index < totalListedTokens; index++) {
            if (
                s_tokenDetails[s_listedTokenIndexToAddress[index]]
                    ._tokenOperationalState == tokenOperationalState.ACTIVE
            ) {
                token[activeTokenCount] = address(
                    s_listedTokenIndexToAddress[index]
                );
                activeTokenCount++;
            }
            continue;
        }

        activeTokens = new address[](activeTokenCount);
        for (uint256 index = 0; index < activeTokenCount; index++) {
            activeTokens[index] = token[index];
        }
        return activeTokens;
    }

    /// @notice This function returns the array of pending token requests addresses.
    function getRequestedTokens()
        external
        view
        returns (address[] memory requestedTokens)
    {
        requestedTokens = new address[](totalRequestedTokens);
        for (uint256 index = 0; index < totalRequestedTokens; index++) {
            requestedTokens[index] = s_requestedTokenIndexToAddress[index];
        }
        return requestedTokens;
    }

    /// @notice this function returns the struct details of a token.
    function getTokenDetails(
        address token
    ) external view returns (address, address, address, uint256, uint8, uint8) {
        tokenDetails memory _tokenDetails = s_tokenDetails[token];

        return (
            _tokenDetails.tokenAddress,
            _tokenDetails.marketOwner,
            _tokenDetails.feeAddress,
            _tokenDetails.timeListed,
            uint8(_tokenDetails._tokenListingState),
            uint8(_tokenDetails._tokenOperationalState)
        );
    }

    function checkIsTokenListed(
        address token
    ) external view isValidAddress(token) returns (bool isListed) {
        if (
            s_tokenDetails[token]._tokenListingState ==
            tokenListingState.LISTED &&
            s_isListed[token]
        ) {
            return isListed = true;
        } else {
            return isListed = false;
        }
    }

    function getTotalRequestedTokens() external view returns (uint256) {
        return totalRequestedTokens;
    }

    function checkIsTokenOperational(
        address token
    ) external view isValidAddress(token) returns (bool operational) {
        if (
            s_tokenDetails[token]._tokenOperationalState ==
            tokenOperationalState.ACTIVE
        ) {
            return operational = true;
        } else {
            return operational = false;
        }
    }
}
