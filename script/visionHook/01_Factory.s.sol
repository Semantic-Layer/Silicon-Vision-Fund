// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Shared.sol";
import {VisionHook} from "../../src/VisionHook.sol";
import {Factory} from "../../src/Factory.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";

contract FactoryScript is Shared {
    function run(address visionHook) public {
        vm.startBroadcast(deployerPrivateKey);
        console2.log("deploying factory.....");
        // https://blog.uniswap.org/uniswap-v3-math-primer
        // price = token1/token0 = 500/0.1 = 5000
        // sqrtPriceX96 = floor(sqrt(A / B) * 2 ** 96) where A and B are the currency reserves
        // sqrtPriceX96=floor(sqrt(5000)*2^96)=5602277097478613991873193822745  (https://www.wolframalpha.com/input?i=floor%28sqrt%285000%29*2%5E96%29)
        // price- ticker converter https://uniswaphooks.com/tool/tick-price
        uint160 sqrtPriceX96 = 5602277097478613991873193822745; // 500/0.1 - {5} (-5 to match the tick spacing)
        // int24 tick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);

        uint160 sqrtPriceBX96 = 6136987079367210512574055639355; // 600/0.1
        int24 tickB = TickMath.getTickAtSqrtPrice(sqrtPriceBX96);

        Factory factory = new Factory(visionHook, address(swapRouter), posm, poolManager, permit2);
        console2.log("factory", address(factory));

        Factory.DeployVisionFundParams memory params = Factory.DeployVisionFundParams({
            fee: 3000,
            tickSpacing: 60,
            sqrtPriceX96: sqrtPriceX96,
            name: "test token",
            symbol: "ttoken",
            decimals: 18,
            aiAgent: deployer,
            systemPrompt: "system prompt"
        });

        console2.log("deploying vision fund.....");

        (PoolKey memory poolKey, address action, address tokenAddr) = factory.deployVisionFund{value: 0.1 ether}(params);

        // add liquidity
        console2.log("add liquidity");
        int24 tickMax = TickMath.maxUsableTick(60);
        uint256 MAX_DEADLINE = 12329839823;
        uint256 amount0 = 0.01 ether;
        VisionHook(visionHook).AddLiquidity{value: amount0}(
            poolKey,
            VisionHook.AddLiquidityParams({
                tickLower: tickB + 1, // add 1 to fit the tick spacing
                tickUpper: tickMax,
                amount0Desired: amount0,
                amount1Desired: 0,
                deadline: MAX_DEADLINE
            }),
            "hello"
        );
    }
}
