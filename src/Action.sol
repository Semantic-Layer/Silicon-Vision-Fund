// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol"; // not for production
import {IERC20Minimal} from "v4-core/src/interfaces/external/IERC20Minimal.sol";

///@dev it's treasury as well as the where ai can perform swap
contract Action {
    address public immutable HOOK;
    PoolSwapTest public immutable POOL_SWAP;
    address public immutable TOKEN; // $ETH-$TOKEN
    address public immutable AI_AGENT;
    PoolKey public POOL_KEY;
    bytes public SYSTEM_PROMPT;

    // todo temperory solution: store prompt msg directly here. we can use offchain event indexing to get user msg instead.
    mapping(uint256 id => Response response) public responses;

    event PromptSent(PoolId indexed poolId, uint256 indexed id, address indexed user, int256 liquidity, bytes prompt);
    event Respond(PoolId indexed poolId, uint256 indexed id, bool decision, bytes response);

    error OnlyAgent();

    modifier onlyAgent() {
        if (msg.sender != AI_AGENT) {
            revert OnlyAgent();
        }
        _;
    }

    struct Response {
        bool decision;
        bytes response;
    }

    struct AddLiquidityParams {
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address to;
        uint256 deadline;
    }

    constructor(
        address poolSwapTest,
        address token,
        address aiAgent,
        PoolKey memory poolKey,
        bytes memory systemPrompt
    ) {
        POOL_SWAP = PoolSwapTest(poolSwapTest);
        TOKEN = token;
        POOL_KEY = poolKey;
        AI_AGENT = aiAgent;
        SYSTEM_PROMPT = systemPrompt;
    }

    // in this example, we only swap $TOKEN to $ETH and $ETH to $TOKEN.
    // we will add support to swap to other token when the univ4 router is ready.
    function performAction(
        IPoolManager.SwapParams memory params,
        PoolId poolId,
        uint256 id,
        bool decision,
        bytes calldata response
    ) public onlyAgent {
        if (decision) {
            POOL_SWAP.swap(POOL_KEY, params, PoolSwapTest.TestSettings({takeClaims: true, settleUsingBurn: false}), "");
        }

        responses[id] = Response({decision: decision, response: response});
        emit Respond(poolId, id, decision, response);
    }

    function setERC20Allowances(address token, address to, uint256 amount) external onlyAgent {
        IERC20Minimal(token).approve(to, amount);
    }
}
