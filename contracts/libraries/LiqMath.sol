// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FullMath} from "./FullMath.sol";

/// @title Math library for computing liquidity
/// @notice expect price range [P0, P1] and current price P in range [P0, P1]
/// if amount of token0 is  x, amount of token1 is  y
/// then L = x/ (1/sqrt{P} - 1/sqrt{P1}) = y/(sqrt{P} - sqrt{P0})
/// ratio = (sqrt{P} - sqrt{P0}) / (1/sqrt{P} - 1/sqrt{P1})
library LiqMath {
    uint256 internal constant X96 = 1 << 96;
    uint256 internal constant X192 = 1 << 192;

    /// @notice Calculates the amount of token0 that should be swapped
    /// @param sqrtPriceX96 Current sqrt price in X96 format
    /// @param sqrtPriceLowerX96 Lower bound sqrt price in X96 format
    /// @param sqrtPriceUpperX96 Upper bound sqrt price in X96 format
    /// @param totalAmount Total amount of token0 input
    /// @return swapAmount Amount of token0 that should be swapped
    /// @dev 
    /// (x * price) / (totalAmount - x) = ratio
    /// x = totalAmount * ratio / (price + ratio)
    function getToken0SwapAmount(
        uint160 sqrtPriceX96,
        uint160 sqrtPriceLowerX96,
        uint160 sqrtPriceUpperX96,
        uint256 totalAmount
    ) internal pure returns (uint256 swapAmount) {
        require(sqrtPriceLowerX96 < sqrtPriceUpperX96, "Invalid price range");
        // If current price is below or equal to lower bound
        if (sqrtPriceX96 <= sqrtPriceLowerX96) {
            swapAmount = totalAmount;
            return swapAmount;
        }
        // If current price is above or equal to upper bound
        if (sqrtPriceX96 >= sqrtPriceUpperX96) {
            swapAmount = 0;
            return swapAmount;
        }

        uint256 numerator = sqrtPriceX96 - sqrtPriceLowerX96;
        uint256 denominator = (X192 / sqrtPriceX96) - (X192 / sqrtPriceUpperX96);
        uint256 ratio = numerator * X96 / denominator;

        uint256 priceX96 = FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, 1 << 96);
        swapAmount = totalAmount * ratio / (priceX96 + ratio);
    }

    /// @notice Calculates the amount of token1 that should be swapped
    /// @param sqrtPriceX96 Current sqrt price in X96 format
    /// @param sqrtPriceLowerX96 Lower bound sqrt price in X96 format
    /// @param sqrtPriceUpperX96 Upper bound sqrt price in X96 format
    /// @param totalAmount Total amount of token1 input
    /// @return swapAmount Amount of token1 that should be swapped
    /// @dev 
    /// (totalAmount - y) / (y / price) = ratio
    /// y = (totalAmount * price) / (price + ratio)
    function getToken1SwapAmount(
        uint160 sqrtPriceX96,
        uint160 sqrtPriceLowerX96,
        uint160 sqrtPriceUpperX96,
        uint256 totalAmount
    ) internal pure returns (uint256 swapAmount) {
        require(sqrtPriceLowerX96 < sqrtPriceUpperX96, "Invalid price range");
        // If current price is below or equal to lower bound
        if (sqrtPriceX96 <= sqrtPriceLowerX96) {
            swapAmount = 0;
            return swapAmount;
        }
        // If current price is above or equal to upper bound
        if (sqrtPriceX96 >= sqrtPriceUpperX96) {
            swapAmount = totalAmount;
            return swapAmount;
        }
        uint256 numerator = sqrtPriceX96 - sqrtPriceLowerX96;
        uint256 denominator = (X192 / sqrtPriceX96) - (X192 / sqrtPriceUpperX96);
        uint256 ratio = numerator * X96 / denominator;

        uint256 priceX96 = FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, 1 << 96);
        swapAmount = totalAmount * priceX96 / (priceX96 + ratio);
    }
}
