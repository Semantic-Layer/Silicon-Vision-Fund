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
/**
 * poolModifyLiquidityTest
 * @title action contract
 * @notice new action contract should be deployed with new pool.
 */

contract Action is IAction {



    address public immutable TOKEN; // $TOKEN-$ETH
    address public immutable AI_AGENT;
    PoolId public  POOL_ID;
    bytes public SYSTEM_PROMPT;

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

    constructor(
        address token,
        PoolId poolId,
        address aiAgent,
        bytes memory systemPrompt
    ) {
        TOKEN = token;
        POOL_ID = poolId;
        AI_AGENT = aiAgent;
        SYSTEM_PROMPT = systemPrompt;
    }

    modifier ensure(uint256 deadline) {
        if (deadline < block.timestamp) revert ExpiredPastDeadline();
        _;
    }

    /**
     * user sends prompt msg by adding liqudity with at least 0.01 eth in Action contract. by doing so:
     * 1. action contract can define its own rules for sending prompt when adding liqudity
     * 2. it won't affect people's normal interaction with the pool
     * 3. we can implement the lqiduity lock for users want to send prompt only
     * @param params AddLiquidityParams
     * @param prompt user prompt msg
     */
    function addLiqudity(IPoolManager.ModifyLiquidityParams calldata params, uint256 deadline,bytes calldata prompt)
        external
        ensure(deadline)
        returns (uint128 liquidity)
    {
        bytes memory hookData = abi.encode(POOL_ID, id++, msg.sender, liquidity, prompt);
    }

    function performSwap(address tokenToSell, address tokenToBuy) external override {}
}
