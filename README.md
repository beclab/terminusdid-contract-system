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
$ forge script script/DeployScript.s.sol:DeployScript --rpc-url $GOERLI_RPC_URL --broadcast --verify --slow -vvvv
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
