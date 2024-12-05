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

    // called by ai agent only to perform swap with treasury tokens
    function performSwap(address tokenToSell, address tokenToBuy) external;
}
