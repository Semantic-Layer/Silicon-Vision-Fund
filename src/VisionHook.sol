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
import "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IAction} from "./IAction.sol";
import {SafeCast} from "v4-core/src/libraries/SafeCast.sol";

contract VisionHook is BaseHook {
    using PoolIdLibrary for PoolKey;
    using SafeCast for int128;

    uint256 constant LOCK_WINDOW = 1 days;
    uint256 constant amountThreshold= 0.01 ether;
    IAction public ACTION_CONTRACT;
    /**
     * @dev we implement lp locking by having a 1:1 nft mapping between our nft and univ4 lp nft
     * the uninft is minted to the hook contract itself.
     * user will be issued an nft that can be used to redeem back the uninft after locking window.
     */
    mapping(PoolId poolId => mapping(uint256 nftId => uint256 uniNftId)) nft2UniNFT;


    event PromptSent(PoolId indexed poolId, uint256 indexed id, address indexed user, int256 liquidity, bytes prompt);

    error ErrSafeCast();
    error ExpiredPastDeadline();

    modifier ensure(uint256 deadline) {
        if (deadline < block.timestamp) revert ExpiredPastDeadline();
        _;
    }

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
    // It sends prompt only when called by address action contract (to have liquitiy lock)
    // todo find better ways to implement liquidity lock
    // dev can defines adding liqudity rules on the action contract side
    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override onlyValidPools(key.hooks) returns (bytes4) {
        if (hookData.length == 0 || sender != address(ACTION_CONTRACT)) return BaseHook.beforeAddLiquidity.selector;

        // safecast
        int128 liquidity = int128(params.liquidityDelta);
        if (liquidity != params.liquidityDelta) {
            revert ErrSafeCast();
        }

        uint256 amount0 = LiquidityAmounts.getAmount0ForLiquidity(
            TickMath.getSqrtPriceAtTick(params.tickLower),
            TickMath.getSqrtPriceAtTick(params.tickUpper),
            liquidity.toUint128()
        );

        // send prompt when threshold is met
        if (amount0 >= amountThreshold) {
            (uint256 id, address user, bytes memory prompt) = abi.decode(hookData, (uint256, address, bytes));
            _sendPrompt(key.toId(), id, user, params.liquidityDelta, prompt);
        }

        return BaseHook.beforeAddLiquidity.selector;
    }

    function _sendPrompt(PoolId poolId, uint256 id, address user, int256 liquidity, bytes memory prompt) internal {
        emit PromptSent(poolId, id, user, liquidity, prompt);
    }
}
