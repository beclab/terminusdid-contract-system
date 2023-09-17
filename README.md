## DID-CONTRACTS

## Usage

### Build

```shell
$ forge build
```

### Test

supports Foundry test and hardhat test

- Foundry

```shell
$ forge test
```

- Hardhat

require node version >= 16

```shell
$ npx hardhat test
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
