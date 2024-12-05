// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAction} from "./IAction.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol"; // not for production
import {PoolModifyLiquidityTestNoChecks} from "v4-core/src/test/PoolModifyLiquidityTestNoChecks.sol"; // not for production;
import "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";

///@dev it's treasury as well as the where ai can perform swap
contract Action {
    PoolSwapTest public immutable POOL_SWAP;
    address public immutable TOKEN; // $TOKEN-$ETH
    address public immutable AI_AGENT;
    PoolKey public POOL_KEY;
    bytes public SYSTEM_PROMPT;

    error OnlyAgent();

    modifier onlyAgent() {
        if (msg.sender != AI_AGENT) {
            revert OnlyAgent();
        }
    }

    struct AddLiquidityParams {
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address to;
        uint256 deadline;
    }

    constructor(
        address poolSwapTest,
        address token,
        PoolKey memory poolKey,
        address aiAgent,
        bytes memory systemPrompt
    ) {
        POOL_SWAP = PoolSwapTest(poolSwapTest);
        TOKEN = token;
        POOL_KEY = poolKey;
        AI_AGENT = aiAgent;
        SYSTEM_PROMPT = systemPrompt;
    }

    // in this example, we only swap $TOKEN to $ETH and $ETH to $TOKEN.
    // we will add support to swap to other token when the univ4 router is ready.
    function performSwap(IPoolManager.SwapParams memory params) external override {
        POOL_SWAP.swap(POOL_KEY, params, PoolSwapTest.TestSettings({takeClaims: true, settleUsingBurn: false}), "");
    }
}
