-include .env

# build
build:; FOUNDRY_PROFILE=solx forge build

# deploy

deployLimitMarket:; forge script script/04_DeployLimitMarket.s.sol:DeployLimitMarket --rpc-url $(LOCAL_RPC_URL) --account DevKey01  --broadcast -vvvv
deployEnforcer:; forge script script/DeployEnforcer_v1.s.sol:DeployEnforcer_v1 --rpc-url $(LOCAL_RPC_URL) --account DevKey01  --broadcast -vvvv
deployTokenManager:;FOUNDRY_PROFILE=solx forge script script/02_DeployTokenManager.s.sol:DeployTokenManager --rpc-url $(LOCAL_RPC_URL) --account DevKey01  --broadcast -vvvv
deployProtocolManager:;FOUNDRY_PROFILE=solx forge script script/01_DeployProtocolManager.s.sol:DeployProtocolManager --rpc-url $(LOCAL_RPC_URL) --account DevKey01  --broadcast -vvvv
deployBorrowRequestFactory:; forge script script/05_DeployBorrowRequestFactory.s.sol:DeployBorrowRequestFactory --rpc-url $(LOCAL_RPC_URL) --account DevKey01  --broadcast -vvvvv
deployLendRequestFactory:; forge script script/DeployLendRequestFactory.s.sol:DeployLendRequestFactory --rpc-url $(LOCAL_RPC_URL) --account DevKey01  --broadcast -vvvv


# interactions
SupportedTokenInteractions:; forge script script/interactions.s.sol:SupportedTokenInteractions  --rpc-url $(LOCAL_RPC_URL) --account DevKey01  --broadcast -vvvv
LimitMarketInteractions:; forge script script/interactions.s.sol:LimitMarketInteractions  --rpc-url $(LOCAL_RPC_URL) --account DevKey01 --broadcast -vvvv
EnforcerInteractions:; forge script script/interactions.s.sol:EnforcerInteractions executeLoanRequests --rpc-url $(LOCAL_RPC_URL) --account DevKey01  --broadcast -vvvv
BorrowRequestInteractions:; forge script script/interactions.s.sol:BorrowRequestInteractions --rpc-url $(LOCAL_RPC_URL) --account DevKey01  --broadcast -vvvv
BorrowRequestFactoryInteractions:; forge script script/interactions.s.sol:BorrowRequestFactoryInteractions --rpc-url $(LOCAL_RPC_URL) --account DevKey01  --broadcast -vvvv

