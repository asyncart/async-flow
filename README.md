# Async Art Flow Contracts

This repository manages the AsyncArtwork NFT system on the Flow chain. The Flow-specific code lives in the `cadence` folder. This includes the AsyncArtwork contract, the contracts it depends on as well as many `transactions` and `scripts` that users and Async Art will run. More detail can be found in the README of each directory within `cadence`.

There is also a `test` directory which contains unit and integrations tests. Details
on the test suite, including how to run it are found in its README.

# Setup

- Clone the repository
- Ensure that you have Python3 installed: https://www.python.org/downloads/
- Ensure Flow CLI is installed: https://docs.onflow.org/flow-cli/install/
- Ensure that you have Pytest installed: (pip3 install -U pytest)

# Deploy

Deploy AsyncArtwork.

`flow accounts add-contract AsyncArtwork ./cadence/contracts/AsyncArtwork.cdc --signer <contract deployer account> --network <emulator/testnet/mainnet>`

The deployer of the contract will be granted the critical `Minter` and `Admin` resources which enable them to administrate the contract. 
To move these admin privileges to another account, see `cadence/transactions/moveMinter.cdc` and `cadence/transactions/moveAdmin.cdc`.

# Administration 

To administrate AsyncArtwork contracts, see `cadence/transactions`.

### Notes