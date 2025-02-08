-include .env

# build
build:; forge build

# deploy

deployLimitMarket:; forge script script/DeployLimitMarket.s.sol:DeployLimitMarket --rpc-url $(LOCAL_RPC_URL) --account localKey1  --broadcast -v
deployEnforcer:; forge script script/DeployEnforcer_v1.s.sol:DeployEnforcer_v1 --rpc-url $(LOCAL_RPC_URL) --account localKey1  --broadcast -v
deploySupportedTokens:; forge script script/DeploySupportedTokens.s.sol:DeploySupportedTokens --rpc-url $(LOCAL_RPC_URL) --account localKey1  --broadcast -v
deployBorrowRequestFactory:; forge script script/DeployBorrowRequestFactory.s.sol:DeployBorrowRequestFactory --rpc-url $(LOCAL_RPC_URL) --account localKey1  --broadcast -v
deployLendRequestFactory:; forge script script/DeployLendRequestFactory.s.sol:DeployLendRequestFactory --rpc-url $(LOCAL_RPC_URL) --account localKey1  --broadcast -v


# interactions
SupportedTokenInteractions:; forge script script/interactions.s.sol:SupportedTokenInteractions  --rpc-url $(LOCAL_RPC_URL) --account localKey1  --broadcast -v
LimitMarketInteractions:; forge script script/interactions.s.sol:LimitMarketInteractions  --rpc-url $(LOCAL_RPC_URL) --account localKey1 --broadcast -v
EnforcerInteractions:; forge script script/interactions.s.sol:EnforcerInteractions executeLoanRequests --rpc-url $(LOCAL_RPC_URL) --account localKey1  --broadcast -v
BorrowRequestInteractions:; forge script script/interactions.s.sol:BorrowRequestInteractions --rpc-url $(LOCAL_RPC_URL) --account localKey1  --broadcast -v
BorrowRequestFactoryInteractions:; forge script script/interactions.s.sol:BorrowRequestFactoryInteractions --rpc-url $(LOCAL_RPC_URL) --account localKey1  --broadcast -vvv

