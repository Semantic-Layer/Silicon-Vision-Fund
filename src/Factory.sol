// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {ERC721, ERC721TokenReceiver} from "solmate/src/tokens/ERC721.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {Action} from "./Action.sol";
import {Token} from "./Token.sol";

import {EasyPosm} from "../test/utils/EasyPosm.sol";

contract Factory is ERC721TokenReceiver {
    using EasyPosm for IPositionManager;

    ///@dev VisionHook address

    address public immutable hook;

    ///@dev univ4 poolManager contract
    IPoolManager public immutable poolManager;

    ///@dev univ4 PoolSwapTest
    address public immutable poolSwapTest;

    IPositionManager public immutable positionManager;

    IAllowanceTransfer public immutable permit2;


    // for deployed funds
    PoolId[] public pools;

    ///@dev pool id => action contract address
    mapping(PoolId poolId => address action) actions; 

    error ZeroValue();
    error ZeroLiquidity();

    constructor(
        address _hook,
        address _poolSwapTest,
        IPositionManager _posm,
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
        if (msg.value == 0) revert ZeroValue();
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

        PoolId id = key.toId();
        pools.push(id);
        actions[id] = action;

        token.mint(action);

        _approve(token);

        // add full range liquidity with the 500 tokens and msg.value
        int24 tickLower = TickMath.minUsableTick(params.tickSpacing);
        int24 tickUpper = TickMath.maxUsableTick(params.tickSpacing);
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            params.sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            msg.value,
            token.balanceOf(address(this))
        );

        if (liquidity == 0) revert ZeroLiquidity();

        positionManager.mint(
            key,
            tickLower,
            tickUpper,
            liquidity,
            msg.value,
            token.balanceOf(address(this)),
            msg.sender, // caller receives the lp nft.
            block.timestamp,
            ""
        );

        // return the excess amount of token to msg.msg.sender
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }
    ///@dev return the amount of total deployed pools
    function totalPoolLength() public view returns(uint256) {
        return pools.length;
    }

    ///@dev return all pools
    function AllPools() public view returns (PoolId[] memory) {
        return pools;
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
