// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract LoanContract is Ownable(msg.sender), ReentrancyGuard {
    using SafeMath for uint256;

    // Loan details
    address public borrower;
    address public collateralToken;
    address public loanToken;
    uint256 public loanAmount;
    uint256 public collateralAmount;   
    uint256 public loanStart;
    uint256 public loanDuration;
    uint256 public liquidationThreshold;
    uint256 public rangeOrderThreshold;

    bool public isLiquidated;

    AggregatorV3Interface public priceFeed;

    event LoanRepaid(address indexed borrower);
    event LoanLiquidated(address indexed liquidator);

    constructor(
        address _borrower,
        address _collateralToken,
        address _loanToken,
        uint256 _loanAmount,
        uint256 _collateralAmount,
        uint256 _loanDuration,
        uint256 _liquidationThreshold,
        uint256 _rangeOrderThreshold,
        address _priceFeed
    ) {
        borrower = _borrower;
        collateralToken = _collateralToken;
        loanToken = _loanToken;
        loanAmount = _loanAmount;
        collateralAmount = _collateralAmount;
        loanDuration = _loanDuration;
        liquidationThreshold = _liquidationThreshold;
        rangeOrderThreshold = _rangeOrderThreshold;
        priceFeed = AggregatorV3Interface(_priceFeed);
        loanStart = block.timestamp;
    }

    function repayLoan() external nonReentrant {
        require(msg.sender == borrower, "Only borrower can repay");
        require(!isLiquidated, "Loan already liquidated");
        require(block.timestamp <= loanStart + loanDuration, "Loan term expired");

        // Logic to transfer loanToken back to lender and unlock collateral

        emit LoanRepaid(msg.sender);
    }

    function checkLiquidationConditions() public view returns (bool withinRange, bool belowThreshold) {
        (, int256 price, , ,) = priceFeed.latestRoundData();
        uint256 collateralValue = uint256(price).mul(collateralAmount).div(1e18);

        withinRange = (collateralValue <= rangeOrderThreshold && collateralValue > liquidationThreshold);
        belowThreshold = (collateralValue <= liquidationThreshold);
    }

    function liquidate(address liquidator) external nonReentrant onlyOwner {
        require(!isLiquidated, "Loan already liquidated");
        (bool withinRange, bool belowThreshold) = checkLiquidationConditions();

        require(withinRange || belowThreshold, "Liquidation conditions not met");

        // Logic to liquidate collateral
        isLiquidated = true;

        emit LoanLiquidated(liquidator);
    }
}

