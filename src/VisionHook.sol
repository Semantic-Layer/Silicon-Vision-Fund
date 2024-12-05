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
import {CurrencySettler} from "v4-core/test/utils/CurrencySettler.sol";
import "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {SafeCast} from "v4-core/src/libraries/SafeCast.sol";
import {PositionManager} from "v4-periphery/src/PositionManager.sol";
import {PoolModifyLiquidityTestNoChecks} from "v4-core/src/test/PoolModifyLiquidityTestNoChecks.sol"; // not for production; replace it with the actual router in the future.
import {LPLock} from "./LPLock.sol";
import {IERC20Minimal} from "v4-core/src/interfaces/external/IERC20Minimal.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {EasyPosm} from "../test/utils/EasyPosm.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";

contract VisionHook is BaseHook, LPLock {
    using PoolIdLibrary for PoolKey;
    using EasyPosm for PositionManager;
    using SafeCast for int128;
    using SafeCast for int256;
    using SafeCast for uint256;
    using StateLibrary for IPoolManager;
    using CurrencySettler for Currency;

    uint256 constant amountThreshold = 0.01 ether;

    ///@dev a unique id used to identity prompt msgs.
    uint256 public promptId = 1;

    PositionManager public immutable positionManager;

    IAllowanceTransfer public immutable permit2;

    PoolModifyLiquidityTestNoChecks public immutable poolModifyLiquidityTest;

    event PromptSent(PoolId indexed poolId, uint256 indexed id, address indexed user, int256 liquidity, bytes prompt);

    error ErrSafeCast();
    error ExpiredPastDeadline();
    error TooMuchSlippage();

    modifier ensure(uint256 deadline) {
        if (deadline < block.timestamp) revert ExpiredPastDeadline();
        _;
    }

    constructor(
        IPoolManager _poolManager,
        PoolModifyLiquidityTestNoChecks _poolModifyLiquidityTest,
        address payable _positionManager,
        address _permit2
    ) BaseHook(_poolManager) LPLock(_positionManager) {
        poolModifyLiquidityTest = _poolModifyLiquidityTest;
        positionManager = PositionManager(_positionManager);
        permit2 = IAllowanceTransfer(_permit2);
    }

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

    struct AddLiquidityParams {
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 deadline;
    }

    // to send prompt, user has to add liquidty via this function
    function AddLiquidity(PoolKey calldata key, AddLiquidityParams calldata params, bytes calldata prompt)
        external
        payable
        ensure(params.deadline)
        returns (uint128 liquidity)
    {
        uint256 amount0Before = key.currency0.balanceOfSelf() - msg.value;
        uint256 amount1Before = key.currency1.balanceOfSelf();

        bytes memory hookData = abi.encode(msg.sender, prompt);
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(key.toId());
        liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(params.tickLower),
            TickMath.getSqrtPriceAtTick(params.tickUpper),
            params.amount0Desired,
            params.amount1Desired
        );
        // _mintLPProof(msg.sender, positionManager.nextTokenId());
        IERC20Minimal token = IERC20Minimal(Currency.unwrap(key.currency1));

        token.transferFrom(msg.sender, address(this), params.amount1Desired);

        (uint256 tokenId,) = positionManager.mint(
            key,
            params.tickLower,
            params.tickUpper,
            liquidity,
            params.amount0Desired,
            params.amount1Desired,
            address(this),
            block.timestamp,
            hookData
        );
        _mintLPProof(msg.sender, tokenId);

        // transfer back excess amount
        uint256 amount0After = key.currency0.balanceOfSelf();
        uint256 amount1After = key.currency1.balanceOfSelf();

        if (amount0After > amount0Before) {
            key.currency0.transfer(msg.sender, amount0After - amount0Before);
        }

        if (amount1After > amount1Before) {
            key.currency0.transfer(msg.sender, amount1After - amount1Before);
        }
    }

    // -----------------------------------------------
    // NOTE: see IHooks.sol for function documentation
    // -----------------------------------------------

    // reference: approvePosmCurrency
    function beforeInitialize(address, PoolKey calldata key, uint160) external override returns (bytes4) {
        address token = Currency.unwrap(key.currency1);
        // approve poolManager
        IERC20Minimal(token).approve(address(poolManager), type(uint256).max);
        
        // approve positionManager
        // Because positionManager uses permit2, we must execute 2 permits/approvals.
        IERC20Minimal(token).approve(address(positionManager), type(uint256).max);
        permit2.approve(token, address(positionManager), type(uint160).max, type(uint48).max);
        return BaseHook.beforeInitialize.selector;
    }

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
