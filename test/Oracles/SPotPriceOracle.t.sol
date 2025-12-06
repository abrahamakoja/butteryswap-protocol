// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

// import "forge-std/Test.sol";

import {Test, console} from "forge-std/Test.sol";
import "../../src/oracles/Uniswap/UniswapV2.sol";

/// fake Uniswap V2 factory mapping
contract MockFactory {
    mapping(address => mapping(address => address)) public pairs;

    function setPair(address a, address b, address pair) external {
        pairs[a][b] = pair;
        pairs[b][a] = pair;
    }

    function getPair(address a, address b) external view returns (address) {
        return pairs[a][b];
    }
}

contract SpotPriceOracleTest is Test {
    // MockFactory factory;
    address factory;
    // ERC20Mock token;
    // ERC20Mock weth;
    address weth;
    // address pair;
    UniswapV2 oracle;
    address token;

    function setUp() public {
        // 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f
        // 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2

        factory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

        weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        oracle = new UniswapV2(address(factory), address(weth));
        token = 0x6982508145454Ce325dDbE47a25d4ec3d2311933; // pepe

        // pair = UniswapV2(oracle).getPair(token);
    }

    function testGetSpotPrice() public {
        uint price = oracle.getSpotPrice(address(token));
        // console.log("token price", price);
        // 0.000056533925606145
        // assertEq(price, 0.01e18);
    }
}
