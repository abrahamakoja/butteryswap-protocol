// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {erc20TokenLibrary} from "./erc20TokenLibrary.sol";

abstract contract MemeBase {
    using SafeERC20 for IERC20;

    IERC20 buttertoken = IERC20(0x790C13D9b9052C2c4f9A83D2b0bdf6bc4Cbb4496);
    uint256 collateralAmount = buttertoken.balanceOf(msg.sender);

    // Transfer funds using erc20TokenLibrary
    // erc20TokenLibrary.transferTokens(IERC20(address(tokenAddress)), request.owners[0], address(this).balance);
    // address[3] private   owners  ;

    function withdrawTokenBalance(uint256 amount) external {
        IERC20 token = IERC20(buttertoken);
        uint256 contractBalance = token.balanceOf(address(this));
        if (amount == 0 || amount > contractBalance) revert(); /*revert InvalidWithdrawalAmount(contractBalance, amount)*/
        token.safeTransfer(msg.sender, amount); // Transfer tokens to the owner
            // emit TokensWithdrawn(msg.sender, buttertoken, amount);
    }

    function getTokenBalance() external virtual returns (uint256);
}
