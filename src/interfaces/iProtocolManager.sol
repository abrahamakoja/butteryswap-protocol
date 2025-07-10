// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface iProtocolManager {
    function TokenManager() external view returns (address);
    function FEE_CONTRACT() external view returns (address);
    function BorrowRequestFactory() external view returns (address);
    function Enforcer() external view returns (address);
    function LimitMarket() external view returns (address);
    function calculateCollateralAmountMinusFee(
        uint256
    ) external pure returns (uint256);
    function calculateCancellationFee(uint256) external pure returns (uint256);
    function calculateAmountMinus_OriginationFee(
        uint256
    ) external pure returns (uint256);
    function minimumDeposit() external view returns (uint256);
    function SETTLEMENT_FEE() external view returns (uint256);
    function MAX_ASSET_LIMIT() external view returns (uint256);
    function MAX_OWNERS_LIMIT() external view returns (uint256);
}
