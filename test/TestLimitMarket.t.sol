// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DeployLimitMarket} from "../script/DeployLimitMarket.s.sol";
import {LimitMarket_v1} from "../src/LimitMarket_v1.sol";
import {Enforcer_v1} from "../src/Enforcer_v1.sol";
import {DeployEnforcer_v1} from "../script/DeployEnforcer_v1.s.sol";
import {DeployButterToken} from "../script/DeployButterToken.s.sol";
import {ButterToken} from "../src/ButterToken.sol";

contract TestLimitMarket is Test {
    address USER = makeAddr("user");
    LimitMarket_v1 limitMarket_v1;
    Enforcer_v1 enforcer_v1;
    ButterToken butterToken;
    DeployEnforcer_v1 deployEnforcer_v1;
    DeployLimitMarket deployLimitMarket;
    DeployButterToken deployButterToken;

   function setUp() external {
    deployEnforcer_v1 = new DeployEnforcer_v1();
    deployButterToken = new DeployButterToken();
    deployLimitMarket = new DeployLimitMarket();
    // Deploy the ButterToken contract

    // Deploy the Enforcer and LimitMarket contracts
    enforcer_v1 = deployEnforcer_v1.run();
    butterToken = deployButterToken.run(address(this),USER);
    limitMarket_v1 = deployLimitMarket.run(address(enforcer_v1), address(butterToken));
    // vm.deal(USER, 60000 * 10 ** butterToken.decimals());
    // console.log("USER balance after deal:", butterToken.balanceOf(address(USER)));

    // // uint256 amountToTransfer = 300 * 10 ** butterToken.decimals();
    // // vm.deal(address(this), 300 * 10 ** butterToken.decimals());
    // // Transfer tokens to USER for testing
    // // vm.prank(address(msg.sender)); // Simulate token deployment from deployer
    // // butterToken.transferFrom(address(msg.sender),address(limitMarket_v1), 100 * 10**butterToken.decimals());

    // //  butterToken.approve(address(this), 50 * 10**butterToken.decimals());
    // //   console.log('this token contract',address(butterToken));

    // uint256 initialUserBalance = butterToken.balanceOf(USER);
    // console.log("USER initial balance:", initialUserBalance);
    // // console.log("wtf balance:",10000 * 10**butterToken.decimals());
    // // console.log("sender initial balance:", butterToken.balanceOf(msg.sender));
    // console.log("this initial balance:", butterToken.balanceOf(address(this)));
    // console.log("this initial Limit:", butterToken.balanceOf(address(limitMarket_v1)));
    // // console.log("allowance",butterToken.allowance(address(this),address(this)));
    // // console.log("Limit allowance",butterToken.allowance(address(USER),address(limitMarket_v1)));
    // console.log("address of this",address(this));
    // console.log("address sender",address(msg.sender));
    // console.log("address limit",address(limitMarket_v1));
}



    function testTotalBorrowersCountIsZero()  public view {
        assertEq(limitMarket_v1.totalBorrowersCount(),0);
    }

    function testEnforcerContractIsAccurate() public view{
        console.log('this deployEnforcer_v1 contract',address(enforcer_v1));
        assertEq(limitMarket_v1.getEnforcerContractAddress(),address(enforcer_v1));
    }

    function testTokenContractIsAccurate() public view{ 
        console.log('this token contract',address(butterToken));
        console.log('limit token contract',limitMarket_v1.getTokenContractAddress());
       assertEq(limitMarket_v1.getTokenContractAddress(), address(butterToken));
    }

    function testBorrowFailsWithoutEnoughCollateral()  public {  
        console.log(0* 0**butterToken.decimals(),butterToken.symbol());  
        vm.expectRevert();
        limitMarket_v1.borrow(0* 0**butterToken.decimals());
    }

    function testBorrowWorks() public {
    vm.startPrank(USER);
    
    butterToken.approve(address(limitMarket_v1), 2333 * 10**butterToken.decimals());
    console.log("this script allowance",butterToken.allowance(USER,address(limitMarket_v1)),butterToken.symbol());
    // vm.prank(USER);
     console.log("User:", USER);
    
    limitMarket_v1.borrow( 2333 * 10 ** butterToken.decimals());

      uint256 finalUserBalance = butterToken.balanceOf(address(USER));
    console.log("USER balance after borrow:", finalUserBalance);
    uint256 borrowCount = limitMarket_v1.totalBorrowersCount();
    assertEq(borrowCount, 1);
    console.log("Total borrowers count after borrow:", borrowCount);
    vm.stopPrank();

    // // Check USER balance after borrow
    uint256 finalsenderBalance = butterToken.balanceOf(address(msg.sender));
    console.log("sender balance after borrow:", finalsenderBalance);
    console.log("contract balance after borrow:", butterToken.balanceOf(address(this)));
}

function testLend() public {
    vm.startPrank(USER);
    vm.deal(USER,20* 10e18);
    console.log("lender balance",USER.balance);
    console.log("this balance",address(this).balance);
    console.log("limit balance",address(limitMarket_v1).balance);
    console.log("sender balance",address(msg.sender).balance);
    limitMarket_v1.Lend{value: 6*10e18}();
    vm.stopPrank();
}
}
