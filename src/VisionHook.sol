// SPDX-License-Identifier: MIT
// this hook is built based on full range liqudity
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";

import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";

import {IAction} from "./IAction.sol";

contract VisionHook is BaseHook {
    using PoolIdLibrary for PoolKey;

    IAction public ACTION_CONTRACT;

    event PromptSent(PoolKey indexed key, uint256 indexed id, address indexed user, int256 liquidity, bytes prompt);

    constructor(IPoolManager _poolManager, IAction actionContract) BaseHook(_poolManager) {
        ACTION_CONTRACT = actionContract;
    }

    // function beforeInitialize(address, PoolKey calldata key, uint160 sqrtPriceX96)
    //     external
    //     override
    //     onlyValidPools(key.hooks)
    //     returns (bytes4)
    // {
    //     poolId = key.toId();
    //     return this.beforeInitialize.selector;
    // }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: false,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    // -----------------------------------------------
    // NOTE: see IHooks.sol for function documentation
    // -----------------------------------------------
    // It sends prompt only when called by address action contract
    // dev can defines adding liqudity rules on the action contract side
    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override onlyValidPools(key.hooks) returns (bytes4) {
        if (sender == address(ACTION_CONTRACT)) {
            (uint256 id, address user, bytes memory prompt) = abi.decode(hookData, (uint256, address, bytes));
            _sendPrompt(key, id, user, params.liquidityDelta, prompt);
        }
        return BaseHook.beforeAddLiquidity.selector;
    }

    function _sendPrompt(PoolKey calldata key, uint256 id, address user, int256 liquidity, bytes memory prompt)
        internal
    {
        emit PromptSent(key, id, user, liquidity, prompt);
    }
}
