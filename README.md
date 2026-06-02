## Buttery swap protocol

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**
Buttery swap is a lending and borrowing protocol for erc-20 tokens, it uses a FIFO matching system and a UUPS Proxy for loan request factory.

### Start
- connect to an EVM test net, and deploy script in the script directory, all scripts are labelled chronologically so you know which to install first. make use of the make file commands.
- generate a Keystore for foundry to protect your private keys 

### deploy
the command below deploys the entrypoint contract.
- deployLimitMarket:;FOUNDRY_PROFILE=solx forge script script/04_DeployLimitMarket.s.sol:DeployLimitMarket --rpc-url $(LOCAL_RPC_URL) --account DevKey01  --broadcast -vvvv

