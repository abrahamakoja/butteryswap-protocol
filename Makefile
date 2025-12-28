

-include .env

export

# build
build:;FOUNDRY_PROFILE=solx  forge clean && FOUNDRY_PROFILE=solx forge build  -vvvvv

# deploy

deployLimitMarket:;FOUNDRY_PROFILE=solx forge script script/04_DeployLimitMarket.s.sol:DeployLimitMarket --rpc-url $(LOCAL_RPC_URL) --account DevKey01  --broadcast -vvvv
deployDeployLoanEnforcer:;FOUNDRY_PROFILE=solx forge script script/03_DeployLoanEnforcer.s.sol:DeployLoanEnforcer --rpc-url $(LOCAL_RPC_URL) --account DevKey01  --broadcast -vvvv
deployTokenManager:;FOUNDRY_PROFILE=solx forge script script/02_DeployTokenManager.s.sol:DeployTokenManager --rpc-url $(LOCAL_RPC_URL) --account DevKey01  --broadcast -vvvv
deployProtocolManager:;FOUNDRY_PROFILE=solx forge script script/01_DeployProtocolManager.s.sol:DeployProtocolManager --rpc-url $(LOCAL_RPC_URL) --account DevKey01  --broadcast -vvvv
deployLoanManager:;FOUNDRY_PROFILE=solx forge script script/05_DeployLoanManager.s.sol:DeployLoanManager --rpc-url $(LOCAL_RPC_URL) --account DevKey01  --broadcast -vvvvv
deployBackery:;FOUNDRY_PROFILE=solx forge script script/06_DeployBackery.s.sol:DeployBackery --rpc-url $(LOCAL_RPC_URL) --account DevKey01  --broadcast -vvvv
reset:; FOUNDRY_PROFILE=solx forge clean && FOUNDRY_PROFILE=solx  forge build  -vvvvv
deployAll:;make reset make deployProtocolManager && make deployTokenManager && make deployDeployLoanEnforcer && make deployLimitMarket && make deployBackery && make deployLoanManager

# test
.SHELL := /bin/bash
.ONESHELL:
.PHONY: mt

mt:
	@PATH="$(HOME)/.foundry/bin:$$PATH"
	@ARGS="$(filter-out $@,$(MAKECMDGOALS))"
	@COUNT=$$(echo $$ARGS | wc -w)

	@if [ $$COUNT -eq 0 ]; then
		echo "❌ Usage: make mt <testFunction> OR make mt <TestFile> <testFunction>"
		exit 1
	elif [ $$COUNT -eq 1 ]; then
		FUNC=$$ARGS
		echo "🧪 Running all tests matching function: $$FUNC"
	elif [ $$COUNT -eq 2 ]; then
		FILE=$$(echo $$ARGS | awk '{print $$1}')
		FUNC=$$(echo $$ARGS | awk '{print $$2}')
		PATH_TO_FILE=$$(find test -type f -name "$${FILE}.t.sol" | head -n1)
		if [ -z "$$PATH_TO_FILE" ]; then
			echo "❌ Could not find test file: $$FILE.t.sol"
			exit 1
		fi
		echo "🧪 Running test $$FUNC in file $$PATH_TO_FILE"
	else
		echo "❌ Too many arguments"
		exit 1
	fi

	# Build before test
	FOUNDRY_PROFILE=solx forge clean
	FOUNDRY_PROFILE=solx forge build

	# Run the test
	if [ $$COUNT -eq 1 ]; then
		FOUNDRY_PROFILE=solx forge test -vvvvv --match-test $$FUNC
	elif [ $$COUNT -eq 2 ]; then
		FOUNDRY_PROFILE=solx forge test -vvvvv --match-path $$PATH_TO_FILE --match-test $$FUNC
	fi

# Prevent "No rule to make target" warnings for extra words
%:
	@:



# fork test

# Use bash for shell
.SHELL := /bin/bash
.ONESHELL:

.PHONY: fork

fork:
	@PATH="$(HOME)/.foundry/bin:$$PATH"
	@ARGS="$(filter-out $@,$(MAKECMDGOALS))"
	@COUNT=$$(echo $$ARGS | wc -w)

	@if [ -z "$$MAINNET_RPC_URL" ]; then
		echo "❌ MAINNET_RPC_URL is not set. Export it first:"
		echo "   export MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY"
		exit 1
	fi

	@if [ $$COUNT -eq 0 ]; then
		echo "❌ Usage: make fork <testFunction> OR make fork <TestFile> <testFunction>"
		exit 1
	elif [ $$COUNT -eq 1 ]; then
		FUNC=$$ARGS
		echo "🧪 Running all tests matching function: $$FUNC (Fork Mode)"
	elif [ $$COUNT -eq 2 ]; then
		FILE=$$(echo $$ARGS | awk '{print $$1}')
		FUNC=$$(echo $$ARGS | awk '{print $$2}')
		PATH_TO_FILE=$$(find test -type f -name "$${FILE}.t.sol" | head -n1)
		if [ -z "$$PATH_TO_FILE" ]; then
			echo "❌ Could not find test file: $$FILE.t.sol"
			exit 1
		fi
		echo "🧪 Running test: $$FUNC in file $$PATH_TO_FILE (Fork Mode)"
	else
		echo "❌ Too many arguments"
		exit 1
	fi

	# Build before running tests
	FOUNDRY_PROFILE=solx forge clean
	FOUNDRY_PROFILE=solx forge build

	# Execute fork test
	if [ $$COUNT -eq 1 ]; then
		FOUNDRY_PROFILE=solx forge test -vvvvv \
			--fork-url "$$MAINNET_RPC_URL" \
			--match-test $$FUNC
	elif [ $$COUNT -eq 2 ]; then
		FOUNDRY_PROFILE=solx forge test -vvvvv \
			--fork-url "$$MAINNET_RPC_URL" \
			--match-path $$PATH_TO_FILE \
			--match-test $$FUNC
	fi

# ignore unused words
%:
	@:
