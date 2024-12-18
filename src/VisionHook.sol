// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
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
import {ERC721, ERC721TokenReceiver} from "solmate/src/tokens/ERC721.sol";

contract VisionHook is BaseHook, LPLock {
    using PoolIdLibrary for PoolKey;
    using EasyPosm for IPositionManager;
    using SafeCast for int128;
    using StateLibrary for IPoolManager;

    int128 constant amountThreshold = 0.001 ether;

    ///@dev a unique id used to identity prompt msgs.
    uint256 public promptId = 1;

    ///@dev signals the nft is minted from addLiquidity function
    uint256 public currLPTokenId;

    // todo temperory solution: store prompt msg directly here. we can use offchain event indexing to get user msg instead.
    mapping(uint256 id => bytes prompt) public userPrompts;

    IPositionManager public immutable positionManager;

    IAllowanceTransfer public immutable permit2;

    event PromptSent(PoolId indexed poolId, uint256 indexed id, address indexed user, bytes prompt);

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
            beforeAddLiquidity: false,
            afterAddLiquidity: true,
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
    function addLiquidity(PoolKey calldata key, AddLiquidityParams memory params, bytes calldata prompt)
        public
        payable
        ensure(params.deadline)
        returns (uint128 liquidity)
    {
        if (msg.value < amountThreshold.toUint128()) revert Threshold(msg.value);
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

        // update current univ4 lp nft id. it will be checked in the afterAddLiquidity hook to ensure user is calling AddLiquidity
        currLPTokenId = positionManager.nextTokenId();

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

    function afterAddLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta delta,
        BalanceDelta,
        bytes calldata hookData
    ) external virtual override returns (bytes4, BalanceDelta) {
        // delta.amount0() should be a negative number because we are taking user's token0 in.
        if (
            hookData.length != 0 && -delta.amount0() >= amountThreshold
                && ERC721(address(positionManager)).ownerOf(currLPTokenId) == address(this) // make sure user is calling addLiquidity
        ) {
            (address user, bytes memory prompt) = abi.decode(hookData, (address, bytes));
            _sendPrompt(key.toId(), promptId++, user, prompt);
        }
        return (BaseHook.afterAddLiquidity.selector, delta);
    }

    function _sendPrompt(PoolId poolId, uint256 id, address user, bytes memory prompt) internal {
        userPrompts[id] = prompt;
        emit PromptSent(poolId, id, user, prompt);
    }

    function tokenURI(uint256 id) public view virtual override returns (string memory) {}
}
