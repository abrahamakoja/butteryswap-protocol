// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ITokenManager {

    
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
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function requestTokenListing(address token) external payable;

    function updateTokenFeeAddress(
        address token,
        address newFeeAddress
    ) external payable;

    function approveTokenRequest(uint256 index) external;

    function unListToken(address token) external payable;

    function emergencyUnListToken(address token) external;

    function getTotalListedActiveTokens()
        external
        view
        returns (address[] memory activeTokens);

    function getRequestedTokens()
        external
        view
        returns (address[] memory requestedTokens);

    function getTokenDetails(
        address token
    )
        external
        view
        returns (
            address,
            address,
            address,
            uint256,
            uint8,
            uint8
        );

    function checkIsTokenListed(
        address token
    ) external view returns (bool isListed);

    function checkIsTokenOperational(
        address token
    ) external view returns (bool operational);
}
