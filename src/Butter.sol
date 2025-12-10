// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Butter is ERC20 {
    constructor() ERC20("Buttery swap", "BUTTER") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}
