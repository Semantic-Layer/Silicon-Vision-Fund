import 'dotenv/config';
import { createPublicClient, createWalletClient, http, parseAbi, zeroAddress, toBytes, toHex } from 'viem';
import { sepolia } from 'viem/chains'
import { privateKeyToAccount } from 'viem/accounts'

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
	"event PromptSent(bytes32 indexed poolId, uint256 indexed id, address indexed user, bytes prompt)"
]);
// const ActionAbi = parseAbi([
// 	" performAction((bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96), bytes32 poolId, uint256 id, bool decision, bytes response)"
// ])
// Action contract ABI with the correct struct representation:
const ActionAbi = [{
	"inputs": [
		{
			"internalType": "struct IPoolManager.SwapParams",
			"name": "params",
			"type": "tuple",
			"components": [
				{
					"internalType": "bool",
					"name": "zeroForOne",
					"type": "bool"
				},
				{
					"internalType": "int256",
					"name": "amountSpecified",
					"type": "int256"
				},
				{
					"internalType": "uint160",
					"name": "sqrtPriceLimitX96",
					"type": "uint160"
				}
			]
		},
		{
			"internalType": "PoolId",
			"name": "poolId",
			"type": "bytes32"
		},
		{
			"internalType": "uint256",
			"name": "id",
			"type": "uint256"
		},
		{
			"internalType": "bool",
			"name": "decision",
			"type": "bool"
		},
		{
			"internalType": "bytes",
			"name": "response",
			"type": "bytes"
		}
	],
	"stateMutability": "nonpayable",
	"type": "function",
	"name": "performAction"
}]

// publicClient for contract events listening
export const publicClient = createPublicClient({
	chain: sepolia,
	transport: http()
})

// walletClient for sending transaction
const walletClient = createWalletClient({
	chain: sepolia,
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
			const { args: { poolId, id, user, prompt } } = log;
			console.log('PromptSent event detected');
			console.log(`poolId: ${poolId}`);
			console.log(`id: ${id}`);
			console.log(`user: ${user}`);
			console.log(`prompt: ${prompt}`);

			// Construct the params for performAction
			const swapParams = {
				zeroForOne: true,             // example: true means token0 -> token1
				amountSpecified: -1000,      // for example, -1000 means exactIn of 1000 units
				sqrtPriceLimitX96: MIN_SQRT_PRICE - 1        // if you have a specific price limit, set it here
			};

			const decision = false;    // Example placeholder
			const response = toHex(toBytes('mock response'));    // Example placeholder

			// Call the stand-alone function to submit the transaction
			await performActionOnChain(swapParams, poolId, id, decision, response);
		}
	},
});



console.log('Listening for PromptSent events...');


