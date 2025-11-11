// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RandomTokens is ERC20 {
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 initialMint
    ) ERC20(_name, _symbol) {
        _mint(msg.sender, initialMint * 10 ** decimals());
    }
}
