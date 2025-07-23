// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILendRequestFactory {
    function getTotalRequests()
        external
        returns (
            uint256 totalNonPrioritizedLendRequests,
            uint256 totalPrioritizedLendRequest
        );
    function createRequest(address lender, bool _priority) external;

    function prioritizeLoanRequest(
        address lender,
        address lendRequest
    ) external;

     function addLiquidity(
        address lender,
        address lendRequest
    ) external;

      function cancelRequest(
        address lender,
        address  lendRequest
    ) external;

    function getNonPrioritizedRequestViaIndex(
        uint256 index
    ) external returns (address);
    function getPrioritizedRequestViaIndex(
        uint256 index
    ) external returns (address);
}
