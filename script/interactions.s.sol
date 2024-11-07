// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {LimitMarket_v1} from "../src/LimitMarket_v1.sol";
import {Enforcer_v1} from "../src/Enforcer_v1.sol";
import {erc20TokenLibrary} from "../src/erc20TokenLibrary.sol";
import {SupportedTokens} from "../src/SupportedTokens.sol";

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

        updateContracts(
            payable(mostrecentlyDeployedLimitMarket),
            mostrecentlyDeployedEnforcer,
            mostrecentlyDeployedST
        );
        borrow(mostrecentlyDeployedLimitMarket, mostrecentlyDeployedJATToken);
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
        address token
    ) public {
        vm.startBroadcast();
        erc20TokenLibrary.approveTokens(
            address(token),
            payable(_mostrecentlyDeployedLimitMarket),
            6660 * 10 ** 18
        );
        LimitMarket_v1(payable(_mostrecentlyDeployedLimitMarket)).borrow(
            666 * 10 ** 18,
            token
        );
        vm.stopBroadcast();
    }

    function lend(address _mostrecentlyDeployedLimitMarket) public {
        vm.startBroadcast();
        LimitMarket_v1(payable(_mostrecentlyDeployedLimitMarket)).lend{
            value: 6 ether
        }();
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
    address mostrecentlyDeployedButterToken;
    address mostrecentlyDeployedJatToken;

    function run() external {
        mostrecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "SupportedTokens",
            block.chainid
        );
        mostrecentlyDeployedButterToken = DevOpsTools
            .get_most_recent_deployment("ButterToken", block.chainid);
        mostrecentlyDeployedJatToken = DevOpsTools.get_most_recent_deployment(
            "JATToken",
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

    function delistToken(address _mostrecentlyDeployed) public {
        vm.startBroadcast();
        SupportedTokens(payable(_mostrecentlyDeployed)).delistToken(
            address(mostrecentlyDeployedJatToken)
        );
        vm.stopBroadcast();
    }
}
