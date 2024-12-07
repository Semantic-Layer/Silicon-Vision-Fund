// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {SafeCast} from "v4-core/src/libraries/SafeCast.sol";
import {IPositionManager} from "v4-periphery/src/PositionManager.sol";
import {IERC20Minimal} from "v4-core/src/interfaces/external/IERC20Minimal.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";

import {EasyPosm} from "../test/utils/EasyPosm.sol";
import {LPLock} from "./LPLock.sol";

contract VisionHook is BaseHook, LPLock {
    using PoolIdLibrary for PoolKey;
    using EasyPosm for IPositionManager;
    using SafeCast for int128;
    using StateLibrary for IPoolManager;

    uint256 constant amountThreshold = 0.001 ether;

    ///@dev a unique id used to identity prompt msgs.
    uint256 public promptId = 1;

    // todo temperory solution: store prompt msg directly here. we can use offchain event indexing to get user msg instead.
    mapping(uint256 id => bytes prompt) public userPrompts;

    IPositionManager public immutable positionManager;

    IAllowanceTransfer public immutable permit2;

    event PromptSent(PoolId indexed poolId, uint256 indexed id, address indexed user, int256 liquidity, bytes prompt);

    error ErrSafeCast();
    error ExpiredPastDeadline();
    error ZeroLiquidity();
    error Threshold(uint256 amount);
    error WrongValue();

    modifier ensure(uint256 deadline) {
        if (deadline < block.timestamp) revert ExpiredPastDeadline();
        _;
    }

    constructor(IPoolManager _poolManager, address payable _positionManager, address _permit2)
        BaseHook(_poolManager)
        LPLock(_positionManager)
    {
        positionManager = IPositionManager(_positionManager);
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
    function AddLiquidity(PoolKey calldata key, AddLiquidityParams memory params, bytes calldata prompt)
        public
        payable
        ensure(params.deadline)
        returns (uint128 liquidity)
    {
        if (msg.value < amountThreshold) revert Threshold(msg.value);
        if (msg.value < params.amount0Desired) revert WrongValue();
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
        if (liquidity == 0) revert ZeroLiquidity();

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
    function beforeInitialize(address, PoolKey calldata key, uint160)
        external
        override
        onlyPoolManager
        returns (bytes4)
    {
        address token = Currency.unwrap(key.currency1);
        // approve permit2
        IERC20Minimal(token).approve(address(permit2), type(uint256).max);

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
        userPrompts[id] = prompt;
        emit PromptSent(poolId, id, user, liquidity, prompt);
    }

    function tokenURI(uint256 id) public view virtual override returns (string memory) {}
}
