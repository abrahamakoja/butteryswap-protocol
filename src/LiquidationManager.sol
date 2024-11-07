// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {LoanContract} from "./LoanContract.sol";

contract LiquidationManager is ReentrancyGuard {
    ISwapRouter public immutable swapRouter;
    LoanContract[] public activeLoans;   
    
    event LoanLiquidated(address indexed loanContract);

     modifier onlyOwner() { 
        if (!isOwner[msg.sender]) revert UnauthorizedTransaction();
        _;        
    } 

    constructor(address _swapRouter) {
        swapRouter = ISwapRouter(_swapRouter);
    }

    function addLoanContract(address loanContractAddress) external onlyOwner {
        activeLoans.push(LoanContract(loanContractAddress));
    }

    function triggerLiquidations() external nonReentrant {
        for (uint256 i = 0; i < activeLoans.length; i++) {
            LoanContract loan = activeLoans[i];
            if (loan.isLiquidated()) continue;

            (bool withinRange, bool belowThreshold) = loan.checkLiquidationConditions();
            if (withinRange || belowThreshold) {
                loan.liquidate(address(this));
                emit LoanLiquidated(address(loan));
            }
        }
    }

    // Add other functions for managing active loans, e.g., removing repaid loans
}
