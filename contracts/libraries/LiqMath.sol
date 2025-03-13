// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Math library for computing liquidity
/// @notice expect price range [P0, P1] and current price P in range [P0, P1]
/// if amount of token0 is  x, amount of token1 is  y
/// then L = x/ (1/sqrt{P} - 1/sqrt{P1}) = y/(sqrt{P} - sqrt{P0})
/// sqrt{P0} = (sqrt{1.0001})^lowerIndex
/// sqrt{P1} = (sqrt{1.0001})^upperIndex
/// Px = 1/sqrt{P} - 1/sqrt{P1}
/// Py = sqrt{P} - sqrt{P0}
/// x = L * Px
/// y = L * Py
library LiqMath {
    uint256 internal constant X96 = 1 << 96;
    uint256 internal constant X192 = 1 << 192;

    /// input is token0 amount => input = x + y * P = L * Px + L * Py * P
    /// L = input / (Px + Py * P)
    /// swapAmount = input - x = y * P
    function getToken0SwapAmount(
        uint160 sqrtPriceX96,
        uint160 sqrtPriceLowerX96,
        uint160 sqrtPriceUpperX96,
        uint256 totalAmount
    ) internal pure returns (uint256 swapAmount) {
        require(sqrtPriceLowerX96 < sqrtPriceUpperX96, "mistake price range");
        // sqrtPriceX96 <=  sqrtPriceLowerX96
        if (sqrtPriceX96 <= sqrtPriceLowerX96) {
            swapAmount = totalAmount;
            return swapAmount;
        }
        // sqrtPriceX96 >=  sqrtPriceUpperX96
        if (sqrtPriceX96 >= sqrtPriceUpperX96) {
            swapAmount = 0;
            return swapAmount;
        }
        uint256 pxX96 = uint256(X192 / sqrtPriceX96) -
            uint256(X192 / sqrtPriceUpperX96);
        uint256 pyX96 = uint256(sqrtPriceX96 - sqrtPriceLowerX96);

        uint256 liq = uint256(totalAmount * X96) /
            (pxX96 + (pyX96 * sqrtPriceX96) / X96);
        swapAmount = (liq * pyX96) / X96;
    }

    /// input is token1 amount => input = x / P + y  =  L * Px / P + L * Py
    /// L = input * P / (Px + Py * P)
    /// swapAmount = input - y = x / P
    function getToken1SwapAmount(
        uint160 sqrtPriceX96,
        uint160 sqrtPriceLowerX96,
        uint160 sqrtPriceUpperX96,
        uint256 totalAmount
    ) internal pure returns (uint256 swapAmount) {
        require(sqrtPriceLowerX96 < sqrtPriceUpperX96, "mistake price range");
        // sqrtPriceX96 <=  sqrtPriceLowerX96
        if (sqrtPriceX96 <= sqrtPriceLowerX96) {
            swapAmount = 0;
            return swapAmount;
        }
        // sqrtPriceX96 >=  sqrtPriceUpperX96
        if (sqrtPriceX96 >= sqrtPriceUpperX96) {
            swapAmount = totalAmount;
            return swapAmount;
        }

        uint256 pxX96 = uint256(X192 / sqrtPriceX96) -
            uint256(X192 / sqrtPriceUpperX96);
        uint256 pyX96 = uint256(sqrtPriceX96 - sqrtPriceLowerX96);

        uint256 liq = uint256(totalAmount * sqrtPriceX96) /
            (pxX96 + (pyX96 * sqrtPriceX96) / X96);
        swapAmount = (liq * pyX96) / X96;
    }
}
