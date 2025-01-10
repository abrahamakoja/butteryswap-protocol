-include .env

build:; forge build
deploy-limitMarket:; forge script script/DeployLimitMarket.s.sol:DeployLimitMarket --rpc-url $(LOCAL_RPC_URL) --account localKey1  --broadcast -vvv
deploy-sTokensLocal:; forge script script/DeploySupportedTokens.s.sol:DeploySupportedTokens --rpc-url $(LOCAL_RPC_URL) --account localKey1  --broadcast -vvv


       
interact-sTokensInteractionsLocal:; forge script script/interactions/supportedTokensInteractions.s.sol:supportedTokensInteractions  --rpc-url $(LOCAL_RPC_URL) --account localKey1  --broadcast -vvvv
interact-sTokensInteractionsLocalDelistToken:; forge script script/interactions/supportedTokensInteractions.s.sol:supportedTokensInteractions delistToken --rpc-url $(LOCAL_RPC_URL) --account localKey1  --broadcast -vvvvv
interact-LimitMarketInteractions:; forge script script/interactions/limitMarketInteractions.s.sol:LimitMarketInteractions borrow --rpc-url $(LOCAL_RPC_URL) --account localKey1  --broadcast -vvvv

