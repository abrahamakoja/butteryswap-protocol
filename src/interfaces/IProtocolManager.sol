// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IProtocolManager {
    function TokenManager() external returns (address);
    function FEE_CONTRACT() external returns (address);
    function BorrowRequestFactory() external returns (address);
    function Executor() external returns (address);
    function TOKEN_MANAGER_CONTRACT() external returns (address);
    function LIMIT_MARKET_CONTRACT() external returns (address);
    function LendRequestFactory() external returns (address);
    function Enforcer() external returns (address);
    function LimitMarket() external returns (address);
    function calculateCollateralAmountMinusFee(
        uint256
    ) external returns (uint256);
    function BATCH_LIMIT() external returns (uint256);
    function LISTING_FEE() external returns (uint256);
    function TOKEN_FEE_ADDRESS_UPDATE_FEE(address) external returns (uint256);
    function PRIORITIZED_BATCH_LIMIT() external returns (uint256);
    function calculateCancellationFee(uint256) external returns (uint256);
    function calculateTokenListingFee(address) external returns (uint256);
    function calculateTokenUnListingFee(address) external returns (uint256);
    function calculateTokenFeeAddressUpdateFee(address) external returns (uint256);
    function calculate_OriginationFee(uint256) external returns (uint256);
    function calculate_CollateralValue(uint256) external returns (uint256);
    function calculate_PriorityFee(uint256) external returns (uint256);
    function minimumDeposit() external returns (uint256);
    function INDEX_PRECISION() external returns (uint256);
    function SETTLEMENT_FEE() external returns (uint256);
    function PRIORITY_FEE() external returns (uint256);
    function MAX_ASSET_LIMIT() external returns (uint256);
    function MAX_OWNERS_LIMIT() external returns (uint256);
}
