include .env

.PHONY: test
test: 
	forge test --match-path test/VisionHook.t.sol -vvvv

.PHONY: deployHook
deployHook:
	forge script script/visionHook/00_VisionHook.s.sol:VisionHookScrpipt --broadcast --rpc-url ${SEPOLIA_RPC_URL} -vvvv


# make deployFactory hook=0xhookAddress
.PHONY: deployFactory
deployFactory:
	forge script script/visionHook/01_Factory.s.sol:FactoryScript ${hook} --sig 'run(address)' --broadcast --rpc-url ${SEPOLIA_RPC_URL} -vvvv

.PHONY: deployPosm
deployPosm:
	forge script script/visionHook/02_Posm.s.sol:DeployPosmTest 0x8C4BcBE6b9eF47855f97E675296FA3F6fafa5F1A 0x000000000022D473030F116dDEE9F6B43aC78BA3 300000 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14 "ETH"  --sig 'run(address,address,uint256,address,string)' --broadcast --rpc-url ${SEPOLIA_RPC_URL} --private-key ${DEPLOYER_PRIVATE_KEY} -vvvv

.PHONY: unichainDeployHook
unichainDeployHook:
	forge script script/visionHook/00_VisionHook.s.sol:VisionHookScrpipt --broadcast --rpc-url ${UNICHAIN_RPC_URL} -vvvv


# make unichainDeployFactory hook=0xhookAddress
.PHONY: unichainDeployFactory
unichainDeployFactory:
	forge script script/visionHook/01_Factory.s.sol:FactoryScript ${hook} --sig 'run(address)' --broadcast --rpc-url ${UNICHAIN_RPC_URL} -vvvv



#### verify contract
.PHONY: verifyPosm
verifyPosm:
	forge verify-contract --chain-id 11155111 --watch  \
	--constructor-args $(shell cast abi-encode "constructor(address,address,uint256,address,address)" 0x8C4BcBE6b9eF47855f97E675296FA3F6fafa5F1A 0x000000000022D473030F116dDEE9F6B43aC78BA3 300000 0x47B1A0D3F698da55cF8c16978efC68837319C83d 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14) \
	${address} PositionManager