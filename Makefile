-include .env

# build
build:; FOUNDRY_PROFILE=solx forge build

# deploy

deployLimitMarket:;FOUNDRY_PROFILE=solx forge script script/04_DeployLimitMarket.s.sol:DeployLimitMarket --rpc-url $(LOCAL_RPC_URL) --account DevKey01  --broadcast -vvvv
deployDeployLoanEnforcer:;FOUNDRY_PROFILE=solx forge script script/03_DeployLoanEnforcer.s.sol:DeployLoanEnforcer --rpc-url $(LOCAL_RPC_URL) --account DevKey01  --broadcast -vvvv
deployTokenManager:;FOUNDRY_PROFILE=solx forge script script/02_DeployTokenManager.s.sol:DeployTokenManager --rpc-url $(LOCAL_RPC_URL) --account DevKey01  --broadcast -vvvv
deployProtocolManager:;FOUNDRY_PROFILE=solx forge script script/01_DeployProtocolManager.s.sol:DeployProtocolManager --rpc-url $(LOCAL_RPC_URL) --account DevKey01  --broadcast -vvvv
deployBorrowRequestFactory:;FOUNDRY_PROFILE=solx forge script script/05_DeployBorrowRequestFactory.s.sol:DeployBorrowRequestFactory --rpc-url $(LOCAL_RPC_URL) --account DevKey01  --broadcast -vvvvv
deployLendRequestFactory:;FOUNDRY_PROFILE=solx forge script script/06_DeployLendRequestFactory.s.sol:DeployLendRequestFactory --rpc-url $(LOCAL_RPC_URL) --account DevKey01  --broadcast -vvvv

deployAll:; make deployProtocolManager && make deployTokenManager && make deployDeployLoanEnforcer && make deployLimitMarket && make deployBorrowRequestFactory && make deployLendRequestFactory