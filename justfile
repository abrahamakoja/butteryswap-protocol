#!/usr/bin/env just --justfile

# load .env file
set dotenv-load

# pass recipe args as positional arguments to commands
set positional-arguments

set export

_default:
  just --list

# utility functions
start_time := `date +%s`
_timer:
    @echo "Task executed in $(($(date +%s) - {{ start_time }})) seconds"

clean-all: && _timer
	forge clean
	rm -rf out

remove-modules: && _timer
	rm -rf .gitmodules
	rm -rf .git/modules/*
	rm -rf lib/forge-std
	touch .gitmodules
	git add .
	git commit -m "modules"


# Install the Modules
install: && _timer
	forge install foundry-rs/forge-std

# Update Dependencies
update: && _timer
	forge update

remap: && _timer
	forge remappings > remappings.txt

# Builds
build: && _timer
	forge clean
	FOUNDRY_PROFILE=solx forge build --names --sizes

# deploy scripts
deploy_tokenManager:  && _timer
	#!/usr/bin/env bash
	echo "Deploying tokenManager to $CHAIN..."
	eval "FOUNDRY_PROFILE=solx forge script DeployTokenManager --rpc-url \"\${${CHAIN}_RPC_URL}\" --account DevKey01  --broadcast -vvvv"
	

format: && _timer
	forge fmt

test-all: && _timer
	FOUNDRY_PROFILE=solx forge test -v

test-gas: && _timer
   FOUNDRY_PROFILE=solx forge test --gas-report

coverage-all: && _timer
	forge coverage --report lcov --allow-failure --no-match-coverage "(script|test)"
	genhtml -o coverage --branch-coverage lcov.info --ignore-errors category --rc derive_function_end_line=0

docs: && _timer
	forge doc --build

mt test: && _timer
	FOUNDRY_PROFILE=solx forge test -vvvvv --match-test {{test}}

mp verbosity path: && _timer
	FOUNDRY_PROFILE=solx forge test -{{verbosity}} --match-path test/{{path}}


