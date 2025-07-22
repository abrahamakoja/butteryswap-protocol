// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
  ================ OVERVIEW ================
  This system consists of:
  - BorrowRequest: A contract where a borrower requests a loan and will later transfer collateral.
  - LendRequest: A contract where a lender offers ETH to fund a loan.
  - Enforcer: Coordinates FIFO-based matching of BorrowRequests and LendRequests.
  - Factories: Used to deploy new BorrowRequest and LendRequest contracts.
*/

/* ----------- Interfaces ----------- */
interface IBorrowRequest {
    function acceptLoan() external;
    function requestedAmount() external view returns (uint256);
}

interface ILendRequest {
    function offerLoan() external payable;
}

/* ----------- BorrowRequest Contract ----------- */
contract BorrowRequest is IBorrowRequest {
    address public borrower;
    uint256 public amount;
    address public collateralToken;
    uint256 public collateralAmount;
    bool public accepted;

    constructor(
        uint256 _amount,
        address _collateralToken,
        uint256 _collateralAmount
    ) {
        borrower = msg.sender;
        amount = _amount;
        collateralToken = _collateralToken;
        collateralAmount = _collateralAmount;
        accepted = false;
    }

    function acceptLoan() external override {
        require(!accepted, "Loan already accepted");

        // Here, you would normally transfer collateral from borrower to loan contract
        // For simplicity, we just mark it as accepted
        accepted = true;
    }

    function requestedAmount() external view override returns (uint256) {
        return amount;
    }
}

/* ----------- LendRequest Contract ----------- */
contract LendRequest is ILendRequest {
    address public lender;
    bool public offered;

    constructor() {
        lender = msg.sender;
        offered = false;
    }

    function offerLoan() external payable override {
        require(!offered, "Already offered");
        require(msg.value > 0, "No ETH sent");

        // Normally, you'd send this ETH to the Borrower or LoanContract
        // Here we just mark as complete
        offered = true;
    }
}

/* ----------- Enforcer Contract ----------- */
contract Enforcer {
    IBorrowRequest[] public borrowQueue;
    ILendRequest[] public lendQueue;

    uint256 public borrowHead;
    uint256 public lendHead;

    // === Add new requests (from factories) ===
    function addBorrowRequest(address _borrow) external {
        borrowQueue.push(IBorrowRequest(_borrow));
    }

    function addLendRequest(address _lender) external {
        lendQueue.push(ILendRequest(_lender));
    }

    // === Match the next pair in FIFO order ===
    function matchNextLoan() external payable {
        require(borrowHead < borrowQueue.length, "No more borrow requests");
        require(lendHead < lendQueue.length, "No more lend requests");

        IBorrowRequest borrower = borrowQueue[borrowHead];
        ILendRequest lender = lendQueue[lendHead];

        uint256 loanAmount = borrower.requestedAmount();
        require(msg.value == loanAmount, "Incorrect ETH sent");

        // Step 1: Send ETH via lender contract
        lender.offerLoan{value: msg.value}();

        // Step 2: Accept loan in borrower contract (e.g. receive collateral)
        borrower.acceptLoan();

        // Move to next pair
        borrowHead++;
        lendHead++;
    }

    // === View functions ===
    function getQueues()
        external
        view
        returns (
            uint256 borrows,
            uint256 lends,
            uint256 borrowIdx,
            uint256 lendIdx
        )
    {
        return (borrowQueue.length, lendQueue.length, borrowHead, lendHead);
    }
}

/* ----------- Factories ----------- */
contract BorrowFactory {
    Enforcer public enforcer;

    constructor(address _enforcer) {
        enforcer = Enforcer(_enforcer);
    }

    function createBorrow(
        uint256 amount,
        address token,
        uint256 collateral
    ) external {
        BorrowRequest req = new BorrowRequest(amount, token, collateral);
        enforcer.addBorrowRequest(address(req));
    }
}

contract LendFactory {
    Enforcer public enforcer;

    constructor(address _enforcer) {
        enforcer = Enforcer(_enforcer);
    }

    function createLend() external payable {
        require(msg.value > 0, "Must send ETH");
        LendRequest req = new LendRequest();
        enforcer.addLendRequest(address(req));
    }
}
