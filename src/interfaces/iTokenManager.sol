// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface iTokenManager {
    function checkTokenIsListed(address token) external view returns (bool);
}
