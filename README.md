## Buttery swap protocol

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**
Buttery swap is a lending and borrowing protocol for erc-20 tokens, it uses a FIFO matching system and a UUPS Proxy for loan request factory.

### Start
- connect to an EVM test net, and deploy script in the script directory, all scripts are labelled chronologically so you know which to install first.

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
