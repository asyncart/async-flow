# Async Art Flow Contracts

This repository manages AsyncArt's on-chain system onFlow. The Flow-specific code lives in the `cadence` folder. This includes the AsyncArtwork and NFTAuction contracts, some standard contracts (i.e. FungibleToken) as well as many `transactions` and `scripts` that users and Async Art will run. More detail can be found in the README of each directory within `cadence`.

There is also a `test` directory which contains unit and integrations tests. Details
on the test suite, including how to run it are found in its README.

# Deployments

The latest contracts have been deployed to testnet. They can be viewed here:

AsyncArtwork: https://flow-view-source.com/testnet/account/0xf35d543e62b62806/contract/AsyncArtwork
Blueprints: https://flow-view-source.com/testnet/account/0xf35d543e62b62806/contract/Blueprints
NFTAuction: https://flow-view-source.com/testnet/account/0xf6c84d7284f77a9c/contract/NFTAuction

# Setup

- Clone the repository
- Ensure that you have Python3 installed: https://www.python.org/downloads/
- Ensure Flow CLI is installed: https://docs.onflow.org/flow-cli/install/
- Ensure that you have Pytest installed: (pip3 install -U pytest)

# How To Deploy

## Automatic Deploy (Recommended)

To quickly deploy AsyncArtwork, Blueprint (WIP), NFTAuction and a few utility contracts to get up and running you can run: `flow project deploy`. This will deploy all contracts as specified in `flow.json` to a local emulator network.

## Manual Deploy

Before you deploy AsyncArtwork or Blueprint on the emulator network you will need to deploy NonFungibleToken, FungibleToken and FlowToken manually. Note that NFTAuction can only be deployed after AsyncArtwork and Blueprint because it depends on them.

Deploy AsyncArtwork.

`flow accounts add-contract AsyncArtwork ./cadence/contracts/AsyncArtwork.cdc --signer <contract deployer account> --network <emulator/testnet/mainnet>`

Deploy Blueprint (NOTE: this is a placeholder, Blueprint is WIP, however NFTAuction depends on it).

`flow accounts add-contract Blueprint ./cadence/contracts/Blueprint.cdc --signer <contract deployer account> --network <emulator/testnet/mainnet>`

Deploy NFTAuction (after the previous two contracts have been deployed)

`flow accounts add-contract NFTAuction ./cadence/contracts/NFTAuction.cdc --signer <contract deployer account> --network <emulator/testnet/mainnet>`

The deployer of the contract will be granted the critical `Minter` and `Admin` resources which enable them to administrate the contract. 

To move these admin privileges to another account, see `cadence/transactions/moveMinter.cdc` and `cadence/transactions/moveAdmin.cdc`.

# Administration 

To administrate Async Art's contracts, see `cadence/transactions`.

# Test

See `test/README.md`

### Notes