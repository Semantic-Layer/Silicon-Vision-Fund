import 'dotenv/config';
import { createPublicClient, createWalletClient, http, parseAbi, privateKeyToAccount, zeroAddress } from 'viem';
import { sepolia } from 'viem/chains'

const MIN_SQRT_PRICE = 4295128739

// read env
const HOOK = process.env.HOOK
const ACTION = process.env.ACTION
const PRIVATE_KEY = process.env.PRIVATE_KEY

// load account from private key
const account = privateKeyToAccount(PRIVATE_KEY);


// load contracts
const HookAbi = parseAbi([
	// Adjust PoolId representation to match actual contract definition
	"event PromptSent((bytes32) indexed poolId, uint256 indexed id, address indexed user, int256 liquidity, bytes prompt)"
]);

const ActionAbi = parseAbi([
	// Adjust IPoolManager.SwapParams and PoolId representations as needed
	"function performAction((address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOutMin, uint160 sqrtPriceLimitX96) params, (bytes32) poolId, uint256 id, bool decision, bytes response) external"
]);

// publicClient for contract events listening
export const publicClient = createPublicClient({
	chain: sepolia,
	transport: http()
})

// walletClient for sending transaction
const walletClient = createWalletClient({
	chain: mainnet,
	transport: http(),
	account,
});

/**
* Standalone function to perform the on-chain action.
* @param {Object} params - IPoolManager.SwapParams
* @param {string|Array} poolId - The poolId tuple, here represented as (bytes32)
* @param {bigint|number} id - The id associated with the prompt
* @param {boolean} decision - The decision (true/false)
* @param {string} response - Bytes response data
*/
async function performActionOnChain(params, poolId, id, decision, response) {
	try {
		const txHash = await walletClient.writeContract({
			address: ACTION,
			abi: ActionAbi,
			functionName: 'performAction',
			args: [params, poolId, id, decision, response],
		});
		console.log(`performAction transaction submitted: ${txHash}`);
	} catch (error) {
		console.error('Error calling performAction:', error);
	}
}

const watch = publicClient.watchContractEvent({
	address: HOOK,
	abi: HookAbi,
	eventName: 'PromptSent',
	onLogs: async (logs) => {
		for (const log of logs) {
			const { args: { poolId, id, user, liquidity, prompt } } = log;
			console.log('PromptSent event detected');
			console.log(`poolId: ${poolId}`);
			console.log(`id: ${id}`);
			console.log(`user: ${user}`);
			console.log(`liquidity: ${liquidity}`);
			console.log(`prompt: ${prompt}`);

			// Construct the params for performAction
			const params = {
				tokenIn: '0xd02119a87AD7BA20F82DDD35CF8452F77A798eF5',       // Example placeholder
				tokenOut: 'zeroAddress',     // Example placeholder
				amountIn: 1000n,                   // Example placeholder
				amountOutMin: 900n,                // Example placeholder
				sqrtPriceLimitX96: MIN_SQRT_PRICE+1              // Example placeholder
			};

			const decision = false;    // Example placeholder
			const response = 'mock response';    // Example placeholder

			// Call the stand-alone function to submit the transaction
			await performActionOnChain(params, poolId, id, decision, response);
		}
	},
});

console.log('Listening for PromptSent events...');


