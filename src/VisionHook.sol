// SPDX-License-Identifier: MIT
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
import {SafeCast} from "v4-core/src/libraries/SafeCast.sol";
import {PositionManager} from "v4-periphery/src/PositionManager.sol";
import {PoolModifyLiquidityTestNoChecks} from "v4-core/src/test/PoolModifyLiquidityTestNoChecks.sol"; // not for production; replace it with the actual router in the future.
import {LPLock} from "./LPLock.sol";

contract VisionHook is BaseHook, LPLock {
    using PoolIdLibrary for PoolKey;
    using SafeCast for int128;

    uint256 constant amountThreshold = 0.01 ether;

    ///@dev a unique id used to identity prompt msgs.
    uint256 public promptId = 1;

    PositionManager public immutable positionManager;

    PoolModifyLiquidityTestNoChecks public immutable poolModifyLiquidityTest;

    event PromptSent(PoolId indexed poolId, uint256 indexed id, address indexed user, int256 liquidity, bytes prompt);

    error ErrSafeCast();
    error ExpiredPastDeadline();

    modifier ensure(uint256 deadline) {
        if (deadline < block.timestamp) revert ExpiredPastDeadline();
        _;
    }

    constructor(
        IPoolManager _poolManager,
        PoolModifyLiquidityTestNoChecks _poolModifyLiquidityTest,
        address payable _positionManager
    ) BaseHook(_poolManager) LPLock(_positionManager) {
        poolModifyLiquidityTest = _poolModifyLiquidityTest;
        positionManager = PositionManager(_positionManager);
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
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

    // to send prompt, user has to add liquidty via this function
    function AddLiquidity(
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata prompt
    ) external {
        bytes memory hookData = abi.encode(msg.sender, prompt);
        _mintLPProof(msg.sender, positionManager.nextTokenId());
        poolModifyLiquidityTest.modifyLiquidity(key, params, hookData);
    }

    // -----------------------------------------------
    // NOTE: see IHooks.sol for function documentation
    // -----------------------------------------------

    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override onlyValidPools(key.hooks) returns (bytes4) {
        if (hookData.length == 0 || sender != address(this)) {
            return BaseHook.beforeAddLiquidity.selector;
        }

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
            (address user, bytes memory prompt) = abi.decode(hookData, (address, bytes));
            _sendPrompt(key.toId(), promptId++, user, params.liquidityDelta, prompt);
        }

        return BaseHook.beforeAddLiquidity.selector;
    }

    function _sendPrompt(PoolId poolId, uint256 id, address user, int256 liquidity, bytes memory prompt) internal {
        emit PromptSent(poolId, id, user, liquidity, prompt);
    }

    function tokenURI(uint256 id) public view virtual override returns (string memory) {}
}
