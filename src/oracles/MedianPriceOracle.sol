// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Minimal interface for Uniswap v4 pool
interface IUniswapV4Pool {
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );
    function liquidity() external view returns (uint128);
}

// Minimal ERC20 interface for decimals
interface IERC20 {
    function decimals() external view returns (uint8);
    function balanceOf(address account) external view returns (uint256);
}

/// @title MedianPriceOracle - Computes median Token/ETH price from multiple v4 pools
contract MedianPriceOracle {
    // token => list of v4 pool addresses
    mapping(address => address[]) public tokenToPools;

    // Minimum liquidity threshold (in raw pool liquidity units)
    uint128 public minLiquidity = 1e15; // adjust as needed

    event MedianPriceComputed(address indexed token, uint256 medianPrice);

    /// @notice Add a pool for a token
    function addPool(address token, address pool) external {
        tokenToPools[token].push(pool);
    }
    /// @notice Compute median Token/ETH price
    function getMedianPrice(
        address token
    ) external view returns (uint256 medianPrice) {
        address[] memory pools = tokenToPools[token];
        require(pools.length >= 3, "Not enough sources");

        uint256[] memory prices = new uint256[](pools.length);
        uint256 count = 0;

        uint8 tokenDecimals = IERC20(token).decimals();
        uint8 ethDecimals = 18;

        // Collect price readings from all pools
        for (uint256 i = 0; i < pools.length; i++) {
            IUniswapV4Pool pool = IUniswapV4Pool(pools[i]);
            if (pool.liquidity() < minLiquidity) {
                continue; // skip low liquidity pools
            }
            (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
            // Compute price: token/ETH
            // price = (sqrtPriceX96^2 / 2^192) * 10^(ETH_decimals - token_decimals)
            uint256 priceRaw = (uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) /
                (2 ** 192);
            uint256 priceAdjusted = (priceRaw * (10 ** ethDecimals)) /
                (10 ** tokenDecimals);
            prices[count] = priceAdjusted;
            count++;
        }

        require(count >= 3, "Not enough valid price sources");

        // Resize prices array to actual count
        uint256[] memory validPrices = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            validPrices[i] = prices[i];
        }

        // Compute median
        medianPrice = computeMedian(validPrices);
        // emit MedianPriceComputed(token, medianPrice);
    }

    /// @notice Compute median Token/ETH price

    /// @notice Internal helper to compute median of array
    function computeMedian(
        uint256[] memory data
    ) internal pure returns (uint256) {
        // Simple insertion sort for small arrays
        for (uint256 i = 1; i < data.length; i++) {
            uint256 key = data[i];
            uint256 j = i;
            while (j > 0 && data[j - 1] > key) {
                data[j] = data[j - 1];
                j--;
            }
            data[j] = key;
        }
        uint256 middle = data.length / 2;
        // If odd, pick middle; if even, average middle two
        if (data.length % 2 == 1) {
            return data[middle];
        } else {
            return (data[middle - 1] + data[middle]) / 2;
        }
    }
}
