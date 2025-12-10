// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6;

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";

contract UniswapV3 {
    address private factory;
    address private weth; // wrapped eth
    uint24 private fee;
    // IProtocolManager private _protocolManager;

    constructor(address _factory, address _weth) {
        factory = _factory;
        weth = _weth;
        // _protocolManager = IProtocolManager(protocolManager);
        fee = 3000;
    }

    function estimateAmountOut(
        address token0,
        uint128 amountIn,
        uint32 secondsAgo
    ) external view returns (uint amountOut) {
        require(token0 != address(0), "invalid token");
        address pool = getPool(token0);
        (int24 tick, ) = OracleLibrary.consult(pool, secondsAgo);
        amountOut = OracleLibrary.getQuoteAtTick(tick, amountIn, token0, weth);
    }

    function getPool(address token0) public view returns (address pool) {
        require(token0 != address(0), "invalid tokens");
        pool = IUniswapV3Factory(factory).getPool(token0, weth, fee);
        require(pool != address(0), "invalid pool");
    }
}
