include .env

.PHONY: test
test: 
	forge test --match-path test/VisionHook.t.sol -vvvv