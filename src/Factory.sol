// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {PositionManager} from "v4-periphery/src/PositionManager.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {ERC721, ERC721TokenReceiver} from "solmate/src/tokens/ERC721.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {Action} from "./Action.sol";
import {Token} from "./Token.sol";

import {EasyPosm} from "../test/utils/EasyPosm.sol";

contract Factory is ERC721TokenReceiver {
    /// @dev Min tick for full range with tick spacing of 60
    int24 internal constant MIN_TICK = -887220;
    /// @dev Max tick for full range with tick spacing of 60
    int24 internal constant MAX_TICK = -MIN_TICK;

    using EasyPosm for PositionManager;
    ///@dev VisionHook address

    address public immutable hook;

    ///@dev univ4 poolManager contract
    IPoolManager public immutable poolManager;

    ///@dev univ4 PoolSwapTest
    address public immutable poolSwapTest;

    PositionManager public immutable positionManager;

    IAllowanceTransfer public immutable permit2;

    constructor(
        address _hook,
        address _poolSwapTest,
        PositionManager _posm,
        IPoolManager _poolManager,
        IAllowanceTransfer _permit2
    ) {
        hook = _hook;
        poolManager = _poolManager;
        poolSwapTest = _poolSwapTest;
        positionManager = _posm;
        permit2 = _permit2;
    }

    struct CreatPoolParams {
        address token; // the $token address of $eth-$token
        uint24 fee;
        int24 tickSpacing;
        uint160 sqrtPriceX96;
    }

    struct DeployActionParams {
        address poolSwapTest;
        address token; // the $token address of $eth-$token
        address aiAgent; // ai agent wallet address
        PoolKey poolKey;
        bytes systemPrompt; // system prompt for the ai agent
    }

    struct DeployTokenParams {
        string name;
        string symbol;
        uint8 decimals;
    }

    struct DeployVisionFundParams {
        // pool related
        uint24 fee;
        int24 tickSpacing;
        uint160 sqrtPriceX96;
        // token related
        string name;
        string symbol;
        uint8 decimals;
        // ai agent related
        address aiAgent; // ai agent wallet address
        bytes systemPrompt; // system prompt for the ai agent
    }

    function deployVisionFund(DeployVisionFundParams calldata params) external payable {
        Token token =
            _deployToken(DeployTokenParams({name: params.name, symbol: params.symbol, decimals: params.decimals}));

        PoolKey memory key = _createPool(
            CreatPoolParams({
                token: address(token),
                fee: params.fee,
                tickSpacing: params.tickSpacing,
                sqrtPriceX96: params.sqrtPriceX96
            })
        );
        address action = _deployAction(
            DeployActionParams({
                poolSwapTest: poolSwapTest,
                token: address(token),
                aiAgent: params.aiAgent,
                poolKey: key,
                systemPrompt: params.systemPrompt
            })
        );

        token.mint(action);

        _approve(token);

        // add full range liquidity with the 500 tokens and msg.value
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            params.sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(MIN_TICK),
            TickMath.getSqrtPriceAtTick(MAX_TICK),
            msg.value,
            token.balanceOf(address(this))
        );

        positionManager.mint(
            key,
            MIN_TICK,
            MAX_TICK,
            liquidity,
            msg.value,
            token.balanceOf(address(this)),
            msg.sender, // caller receives the lp nft.
            block.timestamp,
            ""
        );
    }

    function _createPool(CreatPoolParams memory params) internal returns (PoolKey memory key) {
        // create(initialize) a univ4 pool
        key = PoolKey(
            Currency.wrap(address(0)), Currency.wrap(params.token), params.fee, params.tickSpacing, IHooks(hook)
        );
        poolManager.initialize(key, params.sqrtPriceX96);
    }

    function _deployAction(DeployActionParams memory params) internal returns (address) {
        Action action =
            new Action(params.poolSwapTest, params.token, params.aiAgent, params.poolKey, params.systemPrompt);
        return address(action);
    }

    function _deployToken(DeployTokenParams memory params) internal returns (Token) {
        Token token = new Token(params.name, params.symbol, params.decimals);
        return token;
    }

    function _approve(Token token) internal {
        token.approve(address(permit2), type(uint256).max);
        token.approve(address(poolManager), type(uint256).max);

        token.approve(address(positionManager), type(uint256).max);
        permit2.approve(address(token), address(positionManager), type(uint160).max, type(uint48).max);
    }
}
