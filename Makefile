include .env

.PHONY: test
test: 
	forge test --match-path test/VisionHook.t.sol -vvvv

.PHONY: deployHook
deployHook:
	forge script script/visionHook/00_VisionHook.s.sol:VisionHookScrpipt --broadcast --rpc-url ${SEPOLIA_RPC_URL} -vvvv


# make deployFactory hook=0x3432432dfes
.PHONY: deployFactory
deployFactory:
	forge script script/visionHook/01_Factory.s.sol:FactoryScript ${hook} --sig 'run(address)' --broadcast --rpc-url ${SEPOLIA_RPC_URL} -vvvv


.PHONY: unichainDeployHook
unichainDeployHook:
	forge script script/visionHook/00_VisionHook.s.sol:VisionHookScrpipt --broadcast --rpc-url ${UNICHAIN_RPC_URL} -vvvv


# make unichainDeployFactory hook=0x3432432dfes
.PHONY: unichainDeployFactory
unichainDeployFactory:
	forge script script/visionHook/01_Factory.s.sol:FactoryScript ${hook} --sig 'run(address)' --broadcast --rpc-url ${UNICHAIN_RPC_URL} -vvvv