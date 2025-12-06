// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/lib/contracts/libraries/FixedPoint.sol";

contract UniswapV2 {
    using FixedPoint for *;

    address public immutable factory;
    address public immutable WETH;
    FixedPoint.uq112x112 public fp;

    constructor(address _factory, address _weth) public {
        factory = _factory;
        WETH = _weth;
    }

    /// @notice Returns the spot price of token in terms of WETH
    /// @param token The token for which you want the price
    /// @return priceScaled Price with 1e18 scaling
    function getSpotPrice(
        address token
    ) external returns (uint256 priceScaled) {
        require(token != address(0), "Zero token");

        // Get the pair (token/WETH)
        address pair = IUniswapV2Factory(factory).getPair(token, WETH);
        require(pair != address(0), "Pair does not exist");

        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pair)
            .getReserves();

        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();

        if (token0 == token) {
            // price = reserve1 / reserve0
            fp = FixedPoint.fraction(reserve1, reserve0);
            return fp.mul(1e18).decode144();
        } else {
            // price = reserve0 / reserve1
            fp = FixedPoint.fraction(reserve0, reserve1);
            return fp.mul(1e18).decode144();
        }
    }
}
