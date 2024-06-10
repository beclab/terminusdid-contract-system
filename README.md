# DID-CONTRACTS

## Intro

The main contract in this repo is `TerminusDID`, defined a hierarchical DNS domain-like name system. We call it `Terminus Name (TName)`. 

Theoretically anyone (now can only be operator, a build-in role to maintain contract operation) can register top Tname with metadata (domain, did, notes and allowSubdomain) and sepcify owner of it. For example, Bob is able to register TName `bob` if it is not registered yet. And Bob specified his own address `0x71...245F1` to be the owner of it. 

```
domain: "bob"
did: "did:xxxx"
notes: "example TName for bob"
allowSubdomain: true
```

The `TerminusDID` contract will record his registration and issue an ERC721 token to Bob's address. So that Bob owns the TName. For any subname of Bob's Tnames, for example, intro.bob, only Bob's address is able to register (and contract's operator address is able to register too). Let's change our perspective. For any TName, it can only be registered by his parents TNames owner addresses.

The TName `myterminus.com` is registered by us when the contract is deployed.

Besides the metadata, the `TerminusDID` provides an extensible attribution attached to TName called `Tag`. We introduced a type system to `Tag`, which means not only the `Tag` has name, but also has type. Currently it supports all primitive solidity type (int, uint, bool, string, address, bytes, bytesN ) and array, arrayN, tuple. For example, Bob can define a tag with name `height` and type `uint256` to extend his metadata of TName `bob`. And Bob (and only the Bob can) then need to specify a Tagger address to set the `height` tag. only the Tagger address is able to set the `height` tag. The Tagger can be an EOA address or a contract address. If it is a contract address, Bob can put complicated data validation logic in it. The Tagger then can set (add, update, delete) `height` tag of Bob's TName and all his sub-TNames.

The `TerminusDID` predefined some root tags (rsaPubKey, dnsARecord, authAddresses and latestDID) to root TName, which is empty string `""`, and specify a root tagger. Any TName can set root tags from root tagger. And also a `ratings` tag is defined at TName `app.myterminus.com`. For more info, you can checkout src/taggers.

## Usage

### Build

```shell
forge build
```

### Test

supports Foundry test and hardhat test

- Foundry

```shell
# as ABITest takes a longer time, can run it seperately
forge test --no-match-contract ABITest --gas-report

forge test --match-contract ABITest --gas-report
```

- Hardhat

require node version >= 16

```shell
REPORT_GAS=true npx hardhat test
```

### Format

```shell
forge fmt
```

### Deploy

deploy to op sepolia as example

```shell
# deploy external library ABI.sol optional

# deploy TerminusDID and RootTagger contracts
source .env
forge script script/DeployScript.s.sol:DeployScript --rpc-url $OP_RPC_URL --broadcast --slow -vvvv

# deploy TerminusAppMarketReputation contract
npx hardhat run script/TerminusAppMarketReputation/deploy.js --network op_sepolia
```

## Release History

- [v2.3.1: replace ecrecover with OZ ECDSA lib](https://github.com/Above-Os/did-contracts/releases/tag/v2.3.1)

- [v2.3.0: create tag type system](https://github.com/Above-Os/did-contracts/releases/tag/v2.3)

- [v2.2.0: add upgradeability to terminusDid](https://github.com/Above-Os/did-contracts/releases/tag/v2.2)

- [v2.1.0: implement TerminusDID contract v2.1.0](https://github.com/Above-Os/did-contracts/releases/tag/v2.1) 


## Contact

- [TerminusOS X](https://twitter.com/TerminusOS)
