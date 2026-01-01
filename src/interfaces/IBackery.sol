// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IBackery {
    function mint(address to, uint256 id, uint256 amount) external;
    function burn(address from, uint256 id, uint256 amount) external;
    function getTotalSupply(
        uint256 ID
    ) external view returns (uint256 _totalSupply);
    function getBalance(
        address owner,
        uint256 tokenId
    ) external view returns (uint256 balance);
    function getName(uint256 ID) external view returns (string memory _name);
    function transfer(address receiver, uint256 id, uint256 amount) external;
    function transferFrom(
        address sender,
        address receiver,
        uint256 id,
        uint256 amount
    ) external;

    function approve(address spender, uint256 id, uint256 amount) external;
    function allowance(
        address owner,
        address spender,
        uint256 id
    ) external view returns (uint256);
}
