// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

interface IBacker {
    function toast() external payable returns (uint256 activeLoanID);
}
