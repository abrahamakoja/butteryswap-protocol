// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface iLendRequestFactory {
    function getTotalActiveLendRequestContractCount()
        external
        view
        returns (uint256 numberOfContracts);
    function getLendRequestPositionOnActiveRequestQue(
        address lendRequest
    ) external view returns (uint256 position);
    function getBatchedActiveLendRequestAddresses(
        uint256 startIndex,
        uint256 numberOfResponse,
        uint256 _batchLimit
    ) external view returns (address[] memory);
    function getTotalActivePrioritizedLendRequests(
        uint256 _batchLimit,
        uint256 numOfResponse
    ) external view returns (address[] memory);
    function createRequest(address lender, bool _priority) external;

    function prioritizeLoanRequest(
        address lender,
        address lendRequest
    ) external;
}
