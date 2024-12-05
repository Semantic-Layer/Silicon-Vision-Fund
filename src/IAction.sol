// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";

interface IAction {
    // $TOKEN-$ETH
    function TOKEN() external view returns (address);

    // the univ4 pool id
    function POOL_ID() external view returns (PoolId);

    // the ai agent address
    function AI_AGENT() external view returns (address);

    // the AI system prompt
    function SYSTEM_PROMPT() external view returns (bytes memory);

    /**
     * user sends prompt msg by adding liqudity in Action contract. by doing so:
     * 1. action contract can define its own rules for sending prompt when adding liqudity
     * 2. it won't affect people's normal interaction with the pool
     * 3. we can implement the lqiduity lock for users want to send prompt only
     * @param amount0 token0 amount
     * @param amount1 token1 amount
     * @param prompt user prompt msg
     * @param deadline add lqiudity deadline
     */
    function addLiqudity(uint256 amount0, uint256 amount1, bytes calldata prompt, uint256 deadline)
        external
        returns (uint128 liquidity);

    // called by ai agent only to perform swap with treasury tokens
    function performSwap(address tokenToSell, address tokenToBuy) external;
}
