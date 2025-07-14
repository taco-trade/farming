// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
// solhint-disable-next-line
import {console} from "forge-std/console.sol";
import {LiqMath} from "../../contracts/libraries/LiqMath.sol";
import {TickMath} from "../../contracts/libraries/TickMath.sol";
import {FullMath} from "../../contracts/libraries/FullMath.sol";

contract LiqMathTest is Test {
    
    /// forge-config: default.allow_internal_expect_revert = true
    function test_getToken0SwapAmount_revertsOnInvalidPriceRange() public {
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtRatioAtTick(-60);
        uint160 sqrtPriceLowerX96 = TickMath.getSqrtRatioAtTick(60);
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(0);
        uint256 totalAmount = 1000e18;

        console.log(sqrtPriceX96);
        console.log(sqrtPriceLowerX96);
        console.log(sqrtPriceUpperX96);
        vm.expectRevert();
        LiqMath.getToken0SwapAmount(
            sqrtPriceX96,
            sqrtPriceLowerX96,
            sqrtPriceUpperX96,
            totalAmount
        );
    }
    
    function testFuzz_getToken0SwapAmount(uint256 totalAmount, int24 startTick, int24 endTick) public pure {
        totalAmount = bound(totalAmount, 0.000001 ether, 50000 ether);
        startTick = int24(bound(startTick, -887272 / 2, 887272 / 2));
        endTick = int24(bound(endTick, -887272 / 2, 887272 / 2));
        vm.assume(startTick < endTick);

        uint160 sqrtPriceLowerX96 = TickMath.getSqrtRatioAtTick(startTick);
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtRatioAtTick(endTick);
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(0); // Middle of wide range
        uint256 lastSwapAmount = 0;

        uint256 swapAmount = LiqMath.getToken0SwapAmount(
            sqrtPriceLowerX96,
            sqrtPriceLowerX96,
            sqrtPriceUpperX96,
            totalAmount
        );

        assertEq(lastSwapAmount, swapAmount);
        
        int24 step = (endTick - startTick) / 100;
        if (step == 0) {
            step = 1;
        }
        for (int24 tick = startTick + step; tick <= endTick; tick += step) {
            sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);
            swapAmount = LiqMath.getToken0SwapAmount(
                sqrtPriceX96,
                sqrtPriceLowerX96,
                sqrtPriceUpperX96,
                totalAmount
            ); 
            assertGt(swapAmount, lastSwapAmount);
            lastSwapAmount = swapAmount;
        }

        sqrtPriceX96 = TickMath.getSqrtRatioAtTick(endTick);
        swapAmount = LiqMath.getToken0SwapAmount(
            sqrtPriceX96,
            sqrtPriceLowerX96,
            sqrtPriceUpperX96,
            totalAmount
        );
        assertEq(swapAmount, totalAmount);
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function test_getToken1SwapAmount_revertsOnInvalidPriceRange() public {
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtRatioAtTick(-60);
        uint160 sqrtPriceLowerX96 = TickMath.getSqrtRatioAtTick(60);
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(0);
        uint256 totalAmount = 1000e18;

        console.log(sqrtPriceX96);
        console.log(sqrtPriceLowerX96);
        console.log(sqrtPriceUpperX96);
        vm.expectRevert();
        LiqMath.getToken1SwapAmount(
            sqrtPriceX96,
            sqrtPriceLowerX96,
            sqrtPriceUpperX96,
            totalAmount
        );
    }
    
    function testFuzz_getToken1SwapAmount(uint256 totalAmount, int24 startTick, int24 endTick) public pure {
        totalAmount = bound(totalAmount, 0.000001 ether, 50000 ether);
        startTick = int24(bound(startTick, -887272 / 2, 887272 / 2));
        endTick = int24(bound(endTick, -887272 / 2, 887272 / 2));
        vm.assume(startTick < endTick);

        uint160 sqrtPriceLowerX96 = TickMath.getSqrtRatioAtTick(startTick);
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtRatioAtTick(endTick);
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(0); // Middle of wide range
        uint256 lastSwapAmount = totalAmount; // Start with max since token1 decreases as tick increases

        uint256 swapAmount = LiqMath.getToken1SwapAmount(
            sqrtPriceLowerX96,
            sqrtPriceLowerX96,
            sqrtPriceUpperX96,
            totalAmount
        );

        assertEq(totalAmount, swapAmount); // At lower bound, should swap all token1

        int24 step = (endTick - startTick) / 100;
        if (step == 0) {
            step = 1;
        }
        for (int24 tick = startTick + step; tick <= endTick; tick += step) {
            sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);
            swapAmount = LiqMath.getToken1SwapAmount(
                sqrtPriceX96,
                sqrtPriceLowerX96,
                sqrtPriceUpperX96,
                totalAmount
            ); 
            assertLe(swapAmount, lastSwapAmount); // Token1 swap amount decreases as tick increases
            lastSwapAmount = swapAmount;
        }

        sqrtPriceX96 = TickMath.getSqrtRatioAtTick(endTick);
        swapAmount = LiqMath.getToken1SwapAmount(
            sqrtPriceX96,
            sqrtPriceLowerX96,
            sqrtPriceUpperX96,
            totalAmount
        );
        assertEq(swapAmount, 0);
    }

    function test_validatePriceSlippage() public pure {
        uint256 expectedSqrtPriceX96 = 1000000000000000000;
        uint256 sqrtPriceX96 = 1000000000000000000;
        uint256 priceSlippage = 10000;
        bool isValid = LiqMath.validatePriceSlippage(expectedSqrtPriceX96, sqrtPriceX96, priceSlippage);
        assertEq(isValid, true);

        // 1% slippage price true
        expectedSqrtPriceX96 = 3886365116239809527873001;
        sqrtPriceX96 = 3905748603647311728345088;
        priceSlippage = 10000; // 1%
        isValid = LiqMath.validatePriceSlippage(expectedSqrtPriceX96, sqrtPriceX96, priceSlippage);
        assertEq(isValid, true);

        expectedSqrtPriceX96 = 3905748603647311728345088;
        sqrtPriceX96 = 3886365116239809527873001;
        priceSlippage = 10000; // 1%
        isValid = LiqMath.validatePriceSlippage(expectedSqrtPriceX96, sqrtPriceX96, priceSlippage);
        assertEq(isValid, true);

        // 1% slippage price false
        expectedSqrtPriceX96 = 3886365116239809527873001;
        sqrtPriceX96 = 3905748603647311728345088;
        priceSlippage = 9000; // 1%
        isValid = LiqMath.validatePriceSlippage(expectedSqrtPriceX96, sqrtPriceX96, priceSlippage);
        assertEq(isValid, false);
    }

    function test_getMinAmount() public pure {
        uint256 amount = 1000e18;
        uint256 slippage = 1_000;
        uint256 minAmount = LiqMath.getMinAmount(amount, slippage);
        assertEq(minAmount, 999e18);
    }
}
