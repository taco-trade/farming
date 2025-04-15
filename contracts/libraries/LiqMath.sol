// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FullMath} from "./FullMath.sol";

/// @title Math library for computing liquidity
/// @notice expect price range [P0, P1] and current price P in range [P0, P1]
/// if amount of token0 is  x, amount of token1 is  y
/// then L = x/ (1/sqrt{P} - 1/sqrt{P1}) = y/(sqrt{P} - sqrt{P0})
/// ratio = y / x = (sqrt{P} - sqrt{P0}) / (1/sqrt{P} - 1/sqrt{P1})
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

        uint256 ratio = _ratio(
            sqrtPriceX96,
            sqrtPriceLowerX96,
            sqrtPriceUpperX96
        );
        uint256 priceX96 = FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, 1 << 96);
        swapAmount = (totalAmount * ratio) / (priceX96 + ratio);
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
        uint256 ratio = _ratio(
            sqrtPriceX96,
            sqrtPriceLowerX96,
            sqrtPriceUpperX96
        );
        uint256 priceX96 = FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, 1 << 96);
        swapAmount = (totalAmount * priceX96) / (priceX96 + ratio);
    }

    /// @notice Calculates the amount of token0 or token1 that should be swapped,
    /// depending on the current price and the price range.
    /// @param sqrtPriceX96 Current sqrt price in X96 format
    /// @param sqrtPriceLowerX96 Lower bound sqrt price in X96 format
    /// @param sqrtPriceUpperX96 Upper bound sqrt price in X96 format
    /// @param token0Amount Amount of token0 input
    /// @param token1Amount Amount of token1 input
    /// @return isToken0 true if token0 is the input token, false if token1 is the input token
    /// @return swapAmount Amount of token0 or token1 that should be swapped
    function getSwapAmount(
        uint160 sqrtPriceX96,
        uint160 sqrtPriceLowerX96,
        uint160 sqrtPriceUpperX96,
        uint256 token0Amount,
        uint256 token1Amount
    ) internal pure returns (bool isToken0, uint256 swapAmount) {
        // If current price is below or equal to lower bound, swap token1
        if (sqrtPriceX96 <= sqrtPriceLowerX96) {
            swapAmount = token1Amount;
            return (false, swapAmount);
        }
        // If current price is above or equal to upper bound, swap token0
        if (sqrtPriceX96 >= sqrtPriceUpperX96) {
            swapAmount = token0Amount;
            return (true, swapAmount);
        }

        // If current price is between lower and upper bound
        uint256 ratio = _ratio(
            sqrtPriceX96,
            sqrtPriceLowerX96,
            sqrtPriceUpperX96
        );
        uint256 priceX96 = FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, X96);

        if (token0Amount == 0) {
            swapAmount =
                (token1Amount * priceX96 - ratio * token0Amount * priceX96 / X96) /
                (priceX96 + ratio);
            return (false, swapAmount);
        }

        uint256 currRatio = (token1Amount * X96) / token0Amount;
        
        // Check if ratios are close enough within 0.1% tolerance
        uint256 tolerance = ratio * 5 / 1000; // 0.1% tolerance
        if (currRatio > ratio - tolerance && currRatio < ratio + tolerance) {
            return (false, 0);
        }

        if (currRatio < ratio) {
            swapAmount =
                (ratio * token0Amount - token1Amount * X96) /
                (priceX96 + ratio);
            return (true, swapAmount);
        }

        if (currRatio > ratio) {
            swapAmount =
                (token1Amount * priceX96 - ratio * token0Amount * priceX96 / X96) /
                (priceX96 + ratio);
            return (false, swapAmount);
        }
    }

    /// @notice Calculates the ratio between token1 and token0 amounts for a given price range
    /// @param sqrtPriceX96 Current sqrt price in X96 format
    /// @param sqrtPriceLowerX96 Lower bound sqrt price in X96 format
    /// @param sqrtPriceUpperX96 Upper bound sqrt price in X96 format
    /// @return ratio The calculated ratio between token1 and token0 amounts
    function _ratio(
        uint160 sqrtPriceX96,
        uint160 sqrtPriceLowerX96,
        uint160 sqrtPriceUpperX96
    ) public pure returns (uint256 ratio) {
        uint256 numerator = sqrtPriceX96 - sqrtPriceLowerX96;
        uint256 denominator = (X192 / sqrtPriceX96) -
            (X192 / sqrtPriceUpperX96);
        ratio = (numerator * X96) / denominator;
    }
}
