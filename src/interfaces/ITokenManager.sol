// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ITokenManager {
    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function totalRequestedTokens() external returns (uint256);
    function requestTokenListing(address token) external payable;

    function updateTokenFeeAddress(
        address token,
        address newFeeAddress
    ) external payable;

    function approveTokenRequest(uint256 index) external;

    function unListToken(address token) external payable;

    function emergencyUnListToken(address token) external;

    function getTotalRequestedTokens() external view returns (uint256);

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
    ) external view returns (address, address, address, uint256, uint8, uint8);

    function checkIsTokenListed(
        address token
    ) external view returns (bool isListed);

    function checkIsTokenOperational(
        address token
    ) external view returns (bool operational);
}
