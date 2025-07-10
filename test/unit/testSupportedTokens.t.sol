pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {DeployTokenManager} from "script/DeployTokenManager.s.sol";
import {TokenManager} from "../../src/TokenManager.sol";
import {JATToken} from "../../src/otherToken.sol";
import {ButterToken} from "../../src/ButterToken.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract testTokenManager is Test {
    address OWNER = msg.sender;
    address USER = address(uint160(uint256(keccak256("USER"))));
    DeployTokenManager deployTokenManager;
    TokenManager tokenManager;
    ButterToken butterToken;
    JATToken jATToken;
    ERC20Mock eRC20Mock;

    function setUp() public {
        deployTokenManager = new DeployTokenManager();
        (TokenManager, butterToken, jATToken) = deployTokenManager.run();
    }

    function deployToken() public returns (address token) {
        eRC20Mock = new ERC20Mock("random", "RND", msg.sender, 50_000_000);
        return address(eRC20Mock);
    }

    function test_approveTokenRequestApprovesCorrectly() public {
        vm.startPrank(USER);
        vm.deal(USER, 900 ether);
        address[] memory deployedTokens = new address[](10);
        for (uint256 index = 0; index < deployedTokens.length; index++) {
            deployedTokens[index] = deployToken();
            TokenManager.requestTokenListing{value: 1 ether}(
                address(deployedTokens[index])
            );
        }
        // uint256 requestCountBefore = TokenManager.getPendingTokens().length;

        vm.stopPrank();

        vm.startPrank(OWNER);
        TokenManager.approveTokenRequest(6);
        // uint256 requestCountAfter = TokenManager.getPendingTokens().length;
        vm.stopPrank();

        // assertEq(requestCountBefore, requestCountAfter);
        uint256 position = TokenManager.s_pendingTokenIndex(
            address(TokenManager.s_listed(0))
        );
        address positionRemoved = address(
            TokenManager.s_pendingTokenIndexToAddress(position)
        );
        address[] memory allPending = TokenManager.getPendingTokens();

        assertNotEq(
            address(TokenManager.s_listed(0)),
            address(
                TokenManager.s_pendingTokenRequests(
                    TokenManager.s_pendingTokenIndex(
                        address(TokenManager.s_listed(0))
                    )
                )
            )
        );
    }
}
