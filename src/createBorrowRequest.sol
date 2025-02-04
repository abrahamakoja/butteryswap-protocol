// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

// import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {BorrowRequest_v1} from "./BorrowRequest_v1.sol";
import {erc20TokenLibrary} from "./erc20TokenLibrary.sol";

interface ISupportedTokens {
    function checkTokenIsApproved(address token) external view returns (bool);
}

// LimitMarket_v1 Contract Definition
abstract contract BorrowRequestFactory {

     ////////////////
    /// Errors ///
    //////////////

    error LimitMarket_v1_unSupportedToken(address token);
    // error LimitMarket_v1_NoCollateralSent(uint256 collateral);
    error LimitMarket_v1_TransferFailed(
        address borrowRequest,
        uint256 sentAmount
    );
    error LimitMarket_v1_InsufficientBalance(
        uint256 balance,
        uint256 collateral
    );
    error LimitMarket_v1_InvalidAmount(uint256 balance, uint256 amountSent);
    error LimitMarket_v1_NoAmountSent(uint256 balance, uint256 amountSent);
    error UnauthorizedAccess(address caller);
    // new
    error LimitMarket_v1_InvalidTokenCount(uint256 tokenCount);
    error LimitMarket_v1_NoCollateralSent(uint256 collateralAmount);
    error LimitMarket_v1_EnforcerNotInitialized();
    error LimitMarket_v1_InsufficientAllowance(
        address token,
        uint256 allowance,
        uint256 requiredAmount
    );

    function createBorrowRequest(  uint256 _collateralAmount,
        address[] calldata _tokens,
        address _enforcerContract) external {
         rawCreateBorrowRequest(_collateralAmount,_tokens,_enforcerContract);
    }

     function rawCreateBorrowRequest(
        uint256 collateralAmount,
        address[] calldata tokens,
        address enforcerContract
    ) internal {
        // checks
        if (tokens.length == 0 || tokens.length > 3)
            revert LimitMarket_v1_InvalidTokenCount(tokens.length);
        if (collateralAmount == 0)
            revert LimitMarket_v1_NoCollateralSent(collateralAmount);
       

        for (uint256 index = 0; index < tokens.length; index++) {
            
            // ensure allowance is decrease when cancelled 
               erc20TokenLibrary.increaseAllowance( tokens[index],address(this),collateralAmount);
          
        }

        // effects
        address[2] memory owners = [msg.sender, address(enforcerContract)];
        BorrowRequest_v1 borrowRequest = new BorrowRequest_v1(
            owners,
            collateralAmount,
            tokens,
            block.timestamp
        );

        // if (priority) {
        //     s_loanIsPrioritized[address(borrowRequest)] = true;
        // }
        // userToBorrowRequestAddress[msg.sender].push(address(borrowRequest));
        // totalBorrowRequestArray.push(borrowRequest);

        // emits
        // emit BorrowRequestCreated(
        //     msg.sender,
        //     address(borrowRequest),
        //     collateralAmount
        // );
        // emit TokensDeposited(msg.sender, tokens, collateralAmount);

        // interactions
        for (uint256 index = 0; index < tokens.length; index++) {
            erc20TokenLibrary.transferFromTokens(
                tokens[index],
                msg.sender,
                address(borrowRequest),
                collateralAmount
            );
        }
    }
}
