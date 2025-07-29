// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ITokenManager {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    // event tokenListingRequestCreated(
    //     tokenDetails indexed _tokenDetails,
    //     uint256 indexed tokenIndex
    // );
    event tokenListed(address indexed listedTokenAddress);
    event tokenUnListingRequested(address indexed deListedTokenAddress);
    event tokenUnListed(address indexed deListedTokenAddress);
    event tokenFeeAddressUpdated(
        address indexed token,
        address indexed oldFeeAddress,
        address indexed newFeeAddress
    );
    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function requestTokenListing(address token) external;

    function updateTokenFeeAddress(
        address token,
        address newFeeAddress
    ) external;

    function approveTokenRequest(uint256 index) external;

    function unListToken(address token) external;

    function emergencyUnListToken(address token) external;

    function getTotalListedActiveTokens()
        external
        view
        returns (address[] memory activeTokens);

    function getRequestedTokens()
        external
        view
        returns (address[] memory requestedTokens);

    // function getTokenDetails(
    //     address token
    // ) external view returns (tokenDetails memory _tokenDetails);

    function checkIsTokenListed(
        address token
    ) external view  returns (bool isListed);

    function checkIsTokenOperational(
        address token
    ) external view returns (bool operational);
}
