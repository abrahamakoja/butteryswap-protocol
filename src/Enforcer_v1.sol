// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILimitMarket_v1 {
    function totalActiveBorrowRequestArray(uint256 index) external view returns (address);
    function totalActiveLendRequestArray(uint256 index) external view returns (address);
    function totalBorrowersCount() external view returns (uint256);
    function totalLendersCount() external view returns (uint256);
}

contract Enforcer_v1 {
    address public limitMarketAddress;
    ILimitMarket_v1 limitMarket;

    // Constructor to set LimitMarket contract address
    constructor(address _limitMarketAddress) {
        limitMarketAddress = _limitMarketAddress;
        limitMarket = ILimitMarket_v1(_limitMarketAddress);
    }

    // Function to fetch 10 lend and borrow requests at a time in batches
    function batchFetchRequests(uint256 startIndex) external view returns (address[] memory, address[] memory) {
        uint256 totalBorrowRequests = limitMarket.totalBorrowersCount();
        uint256 totalLendRequests = limitMarket.totalLendersCount();

        uint256 batchLimit = 10;
        uint256 endIndexBorrow = startIndex + batchLimit > totalBorrowRequests ? totalBorrowRequests : startIndex + batchLimit;
        uint256 endIndexLend = startIndex + batchLimit > totalLendRequests ? totalLendRequests : startIndex + batchLimit;

        address[] memory borrowRequests = new address[](endIndexBorrow - startIndex);
        address[] memory lendRequests = new address[](endIndexLend - startIndex);

        for (uint256 i = startIndex; i < endIndexBorrow; i++) {
            borrowRequests[i - startIndex] = limitMarket.totalActiveBorrowRequestArray(i);
        }

        for (uint256 i = startIndex; i < endIndexLend; i++) {
            lendRequests[i - startIndex] = limitMarket.totalActiveLendRequestArray(i);
        }

        return (borrowRequests, lendRequests);
    }
}
