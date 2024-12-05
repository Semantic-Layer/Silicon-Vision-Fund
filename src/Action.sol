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
/**
 * poolModifyLiquidityTest
 * @title action contract
 * @notice new action contract should be deployed with new pool.
 */

contract Action is IAction {
    address public immutable TOKEN; // $TOKEN-$ETH
    address public immutable AI_AGENT;
    PoolKey public POOL_KEY;
    bytes public SYSTEM_PROMPT;
    PoolModifyLiquidityTestNoChecks public immutable POOL_MODIFY_LIQUIDITY;

    uint256 id = 1;

    error ExpiredPastDeadline();
    error PoolNotInitialized();
    error TickSpacingNotDefault();
    error LiquidityDoesntMeetMinimum();

    struct AddLiquidityParams {
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address to;
        uint256 deadline;
    }

    constructor(PoolModifyLiquidityTestNoChecks poolModifyLiquidity, address token, PoolKey memory poolKey, address aiAgent, bytes memory systemPrompt) {
        POOL_MODIFY_LIQUIDITY = poolModifyLiquidity;
        TOKEN = token;
        POOL_KEY = poolKey;
        AI_AGENT = aiAgent;
        SYSTEM_PROMPT = systemPrompt;
    }



    function performSwap(address tokenToSell, address tokenToBuy) external override {}
}
