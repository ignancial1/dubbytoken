## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

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

## Deployments
- **Base Mainnet:** [0x653a2e9e35af2c5548032075f71e69c8356e4287](https://basescan.org/address/0x653a2e9e35af2c5548032075f71e69c8356e4287) — verified ✅
- **Base Sepolia (testnet):** [0x1d6Cb9dc0baC1dc16638c1a18d9a937EB376BAE0](https://sepolia.basescan.org/address/0x1d6Cb9dc0baC1dc16638c1a18d9a937EB376BAE0) — verified ✅

## Stack
- Foundry (forge, cast, anvil)
- Slither (static analysis)
- OpenZeppelin contracts
