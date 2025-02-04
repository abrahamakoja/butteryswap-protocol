// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {LimitMarket_v1} from "../src/LimitMarket_v1.sol";
import {Enforcer_v1} from "../src/Enforcer_v1.sol";
import {erc20TokenLibrary} from "../src/erc20TokenLibrary.sol";
import {SupportedTokens} from "../src/SupportedTokens.sol";
import {BorrowRequest_v1} from "../src/BorrowRequest_v1.sol";

contract LimitMarketInteractions is Script {
    using erc20TokenLibrary for erc20TokenLibrary.tokenData;
    address mostrecentlyDeployedLimitMarket;
    address mostrecentlyDeployedJATToken;
    address mostrecentlyDeployedButterToken;
    address mostrecentlyDeployedEnforcer;
    address mostrecentlyDeployedST;

    function run() external {
        mostrecentlyDeployedLimitMarket = DevOpsTools
            .get_most_recent_deployment("LimitMarket_v1", block.chainid);
        mostrecentlyDeployedButterToken = DevOpsTools
            .get_most_recent_deployment("ButterToken", block.chainid);
        mostrecentlyDeployedJATToken = DevOpsTools.get_most_recent_deployment(
            "JATToken",
            block.chainid
        );
        mostrecentlyDeployedEnforcer = DevOpsTools.get_most_recent_deployment(
            "Enforcer_v1",
            block.chainid
        );
        mostrecentlyDeployedST = DevOpsTools.get_most_recent_deployment(
            "SupportedTokens",
            block.chainid
        );
        address[] memory tokens = new address[](2);
tokens[0] = mostrecentlyDeployedButterToken;
tokens[1] = mostrecentlyDeployedJATToken;


        updateContracts(
            payable(mostrecentlyDeployedLimitMarket),
            mostrecentlyDeployedEnforcer,
            mostrecentlyDeployedST
        );
        borrow(mostrecentlyDeployedLimitMarket, tokens);
        borrow(mostrecentlyDeployedLimitMarket, tokens);
        borrow(mostrecentlyDeployedLimitMarket, tokens);
        priorityBorrow(mostrecentlyDeployedLimitMarket, tokens);
        borrow(mostrecentlyDeployedLimitMarket, tokens);
        borrow(mostrecentlyDeployedLimitMarket, tokens);
        borrow(mostrecentlyDeployedLimitMarket, tokens);
        borrow(mostrecentlyDeployedLimitMarket, tokens);
        priorityBorrow(mostrecentlyDeployedLimitMarket, tokens);
        borrow(mostrecentlyDeployedLimitMarket, tokens);
        priorityBorrow(mostrecentlyDeployedLimitMarket, tokens);
        borrow(mostrecentlyDeployedLimitMarket, tokens);
        borrow(mostrecentlyDeployedLimitMarket, tokens);
        borrow(mostrecentlyDeployedLimitMarket, tokens);
        borrow(mostrecentlyDeployedLimitMarket, tokens);
        borrow(mostrecentlyDeployedLimitMarket, tokens);
        borrow(mostrecentlyDeployedLimitMarket, tokens);
        borrow(mostrecentlyDeployedLimitMarket, tokens);
        priorityBorrow(mostrecentlyDeployedLimitMarket, tokens);
        borrow(mostrecentlyDeployedLimitMarket, tokens);
        borrow(mostrecentlyDeployedLimitMarket, tokens);
        borrow(mostrecentlyDeployedLimitMarket, tokens);
        borrow(mostrecentlyDeployedLimitMarket, tokens);
       

        priorityLend(mostrecentlyDeployedLimitMarket);
        lend(mostrecentlyDeployedLimitMarket);
        lend(mostrecentlyDeployedLimitMarket);
        lend(mostrecentlyDeployedLimitMarket);
        priorityLend(mostrecentlyDeployedLimitMarket);
        lend(mostrecentlyDeployedLimitMarket);
        lend(mostrecentlyDeployedLimitMarket);
        priorityLend(mostrecentlyDeployedLimitMarket);
        lend(mostrecentlyDeployedLimitMarket);
        lend(mostrecentlyDeployedLimitMarket);
        priorityLend(mostrecentlyDeployedLimitMarket);
        lend(mostrecentlyDeployedLimitMarket);
        lend(mostrecentlyDeployedLimitMarket);
        lend(mostrecentlyDeployedLimitMarket);
    }

    function updateContracts(
        address _mostrecentlyDeployedLimitMarket,
        address enforcer,
        address supportedTokenAddress
    ) public {
        vm.startBroadcast();
        console.log("supportedTokenAddress", supportedTokenAddress);
        console.log(
            "_mostrecentlyDeployedLimitMarket",
            _mostrecentlyDeployedLimitMarket
        );
        console.log("enforcer", enforcer);
        LimitMarket_v1(payable(_mostrecentlyDeployedLimitMarket))
            .updateContracts(enforcer, supportedTokenAddress);
        vm.stopBroadcast();
    }

    function borrow(
    address _mostrecentlyDeployedLimitMarket,
    address[] memory token
) public {
    address[] memory tokenAddresses = new address[](token.length);
    for (uint256 index = 0; index < token.length; index++) {
        tokenAddresses[index] = token[index];  // Corrected assignment
        console.log("token", index, ": ", token[index]);
    }
    vm.startBroadcast();

    for (uint256 index = 0; index < token.length; index++) {
        erc20TokenLibrary.approveTokens(
            token[index],  // Corrected token address
            payable(_mostrecentlyDeployedLimitMarket),
            6660 * 10 ** 18
        );
    }

    LimitMarket_v1(payable(_mostrecentlyDeployedLimitMarket)).borrow(
        60 * 10 ** 18,
        tokenAddresses,
        false
    );

    vm.stopBroadcast();
}

    function priorityBorrow(
      address _mostrecentlyDeployedLimitMarket,
    address[] memory token
) public {
    address[] memory tokenAddresses = new address[](token.length);
    for (uint256 index = 0; index < token.length; index++) {
        tokenAddresses[index] = token[index];  // Corrected assignment
        console.log("token", index, ": ", token[index]);
    }
    vm.startBroadcast();

    // for (uint256 index = 0; index < token.length; index++) {
    //     erc20TokenLibrary.approveTokens(
    //         token[index],  // Corrected token address
    //         payable(_mostrecentlyDeployedLimitMarket),
    //         6660 * 10 ** 18
    //     );
    // }

    LimitMarket_v1(payable(_mostrecentlyDeployedLimitMarket)).borrow(
        60 * 10 ** 18,
        tokenAddresses,
        true
    );

    vm.stopBroadcast();
    }

    function lend( address _mostrecentlyDeployedLimitMarket) public {
        vm.startBroadcast();
        LimitMarket_v1(payable(_mostrecentlyDeployedLimitMarket)).lend{
            value: 6 ether
        }(false);
        vm.stopBroadcast();
    }
    function priorityLend(address _mostrecentlyDeployedLimitMarket) public {
        vm.startBroadcast();
        LimitMarket_v1(payable(_mostrecentlyDeployedLimitMarket)).lend{
            value: 6 ether
        }(true);
        vm.stopBroadcast();
    }
}

contract EnforcerInteractions is Script {
    address mostrecentlyDeployedEnforcer;
    address mostrecentlyDeployedLimitMarket;

    function run() external {
        mostrecentlyDeployedEnforcer = DevOpsTools.get_most_recent_deployment(
            "Enforcer_v1",
            block.chainid
        );
        mostrecentlyDeployedLimitMarket = DevOpsTools
            .get_most_recent_deployment("LimitMarket_v1", block.chainid);

        updateLimitMarketContract(
            mostrecentlyDeployedEnforcer,
            mostrecentlyDeployedLimitMarket
        );

        executeLoanRequests(mostrecentlyDeployedEnforcer);
    }

    function updateLimitMarketContract(
        address _mostrecentlyDeployedEnforcer,
        address limitMarket
    ) public {
        vm.startBroadcast();
        Enforcer_v1(payable(_mostrecentlyDeployedEnforcer))
            .updateLimitMarketContract(limitMarket);
        vm.stopBroadcast();
    }

    function executeLoanRequests(address _mostrecentlyDeployedEnforcer) public {
        vm.startBroadcast();
        Enforcer_v1(payable(_mostrecentlyDeployedEnforcer))
            .executeLoanRequests();
        vm.stopBroadcast();
    }
}

contract SupportedTokenInteractions is Script {
    address mostrecentlyDeployed;

    function run() external {
        mostrecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "SupportedTokens",
            block.chainid
        );

        approveTokenRequest(payable(mostrecentlyDeployed));
        approveTokenRequest(payable(mostrecentlyDeployed));
        // delistToken(payable(mostrecentlyDeployed));
        // delistToken(payable(mostrecentlyDeployed));
    }

    function approveTokenRequest(address _mostrecentlyDeployed) public {
        vm.startBroadcast();
        SupportedTokens(payable(_mostrecentlyDeployed)).approveTokenRequest(0);
        vm.stopBroadcast();
    }

    // function delistToken(address _mostrecentlyDeployed) public {
    //     vm.startBroadcast();
    //     SupportedTokens(payable(_mostrecentlyDeployed)).delistToken(
    //         address(mostrecentlyDeployedJatToken)
    //     );
    //     vm.stopBroadcast();
    // }
}

contract BorrowRequestInteractions is Script {
    address _mostrecentlyDeployedEnforcer;
    address mostrecentlyDeployedButterToken;

    function run() external {
        _mostrecentlyDeployedEnforcer = DevOpsTools.get_most_recent_deployment(
            "Enforcer_v1",
            block.chainid
        );
        mostrecentlyDeployedButterToken = DevOpsTools
            .get_most_recent_deployment("ButterToken", block.chainid);

        deployBorrowContract(
            _mostrecentlyDeployedEnforcer,
            mostrecentlyDeployedButterToken
        );
    }

   function deployBorrowContract(
    address mostrecentlyDeployedEnforcer,
    address token
) public {
    address[] memory tokenAddresses = new address[](1);  // Initialize with correct size
    tokenAddresses[0] = token;  // Assign the token address

    vm.startBroadcast();
    BorrowRequest_v1 borrowRequest_v1 = new BorrowRequest_v1(
        [address(msg.sender), address(mostrecentlyDeployedEnforcer)],
        2360 * 10 ** 18,
        tokenAddresses,
        block.timestamp
    );
    borrowRequest_v1.getOwnersAdresses();
    // borrowRequest_v1.cancelRequest();

    console.log("enforcer : ", mostrecentlyDeployedEnforcer);
    console.log("this contract : ", address(this));
    console.log("this sender : ", address(msg.sender));
    vm.stopBroadcast();
}
}
