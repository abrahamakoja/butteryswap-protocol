## Buttery swap protocol


**Buttery swap is a Multi-chain lending and borrowing protocol for erc-20 tokens, it uses a FIFO matching system ,ERC6909Upgradeable contracts for internal tokenization and a UUPS Proxy for loan request factory.**

### Start
- connect to an EVM test net, and deploy script in the script directory, all scripts are labelled chronologically so you know which to install first. make use of the make file commands.
- generate a Keystore for foundry to protect your private keys and replay the ```DevKey01``` label with yours

### deploy
- use ``` make deployAll ``` command to deploy all contracts chronologically. 
- The command ```make deployProtocolManager``` deploys the entrypoint contract.
  
### Notice
this codebase is still in development and is not audited.
