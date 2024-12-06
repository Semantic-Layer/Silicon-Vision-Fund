# Silicon Vision Fund
## Introduction
### What is Silicon Vision Fund?
Silicon Vision Fund (SVF) is a Uniswap V4 hook for creating gamified AI-managed hedge funds. Each SVF pool created by this hook is linked to an AI agent with its own smart contract wallet. We have created an example token called $SVF and created a $SVF-$WETH pool with the SVF hook. 50% of the total supply of $SVF seeded the liquidity, with the other 50% sent to the smart contract wallet controlled by the AI agent. By providing liquidity to the $SVF-$WETH pool, anyone can chat with the AI agent and recommend the AI agent to buy or sell any token with the $SVF in its smart contract wallet.
### Why is it called Silicon Vision Fund?
Short answer: it's a reference to the $100 billion Softbank Vision Fund. Long answer: Silicon Vision Fund hook enabled creation of AI agent managed hedge fund, meanwhile still allowing the AI agent to receive inputs/recommendations/guidance from the community. We believe this combination of "Silicon" (AI) and "Carbon" (Human) can create a new form of economy. Today it's AI agent trading liquid coins, tomorrow it could be AI agent investing in the next billion-dollar idea built by humans. SVF is the first step in building out full automatic capitalism.
### What can SVF be used for?
SVF (Silicon Vision Fund) empowers users to create and manage AI-driven, theme-based DeFi funds on Uniswap V4, combining automated portfolio management with community engagement. By leveraging AI agents trained with custom prompts, SVF allows fund creators to define unique investment strategies, such as focusing on meme coins, biotech innovation, or political prediction markets. Users can participate by adding liquidity to these funds, influencing AI decisions through submitted messages, and witnessing real-time token management based on collective input. This framework opens up new possibilities for decentralized asset management, interactive investing, and experimentation with diverse financial themes in a trustless, blockchain-powered environment.
## Gettting Started
### prerequisite: 
- install [foundry](https://book.getfoundry.sh/getting-started/installation)
- create a `.env` file
    ```bash
    cp .env.example .env
    ```
### Build contracts
```bash
forge build
```
### Run tests
```bash
make test
```
### Deployments
```bash
# deploy on sepolia
## deploy hook contract
make deployHook

## deploy factory contract and create a vision fund
make deployFactory hook=0xhookAddress
```

## Smart Contract Implementation
### Overview
We implemented a beforeAddLiquidity hook that verifies whether a user is eligible to send a message to the AI agent.
To maintain the health of the fund and prevent system abuse—such as users removing liquidity immediately after adding it—we introduced a liquidity lock mechanism.

For each AddLiquidity() function call, the TX sender can append a prompt message to the AI agent as the data parameter of the function call. 
#### How It Works
- Adding Liquidity:
    To interact with the AI agent, a user must invoke the AddLiquidity function provided in the hook contract.

- Minting NFT Proof:

    Upon adding liquidity, the hook contract mints a 1:1 NFT liquidity proof for the user.
    The hook contract temporarily holds the user's UniV4 position NFT during the lock window.
- Redeeming Liquidity:

    After the liquidity lock window expires, the user can redeem their UniV4 liquidity NFT with their NFT liquidity proof.

### Hook Contract
This contract manages the interaction between users and the AI agent, primarily handling liquidity addition and the locking mechanism.

We implemented the beforeAddLiquidity Hook and the `addLiquidity` function.
- Verifies the caller is the hook contract itself.
- Checks that the user provides at least X ETH worth of liquidity tokens.
- Ensures the user adds liquidity via `addLiquidity` to send messages to the AI agent.
    Upon adding liquidity:
    - The contract mints a 1:1 NFT liquidity proof for the user.
    - Temporarily holds the user's UniV4 position NFT.
    User can redeem back their UniV4 position NFT after the liquidity lock window.

### Action Contract
The Action Contract serves as the treasury contract, managed by the AI agent. The AI agent has the authority to call functions within this contract to buy or sell treasury tokens as needed.
### Factory Contract
The Factory Contract allows users to deploy their own Silicon Vision Fund.
#### Key Features:
- Pool Creation:
    Deploys a new pool with the integrated hook contract.
    Instantiates a new Action Contract.
- Token Issuance:
    Creates a new token with a total supply of 1,000 × 10¹⁸.
    Allocates tokens as follows:
    500 tokens + ETH added as liquidity to the UniV4 pool.
    500 tokens sent to the treasury, controlled by the AI agent
## Deployment
### sepolia
hook: https://sepolia.etherscan.io/address/0xdada3eb2873547a49c59ec28d68dc264c962a800

factory: https://sepolia.etherscan.io/address/0x93c39d729BA36931ea83838A59dF5cf5951254E7
