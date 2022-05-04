# Contracts

There are ten Cadence smart contracts in this folder.

`NonFungibleToken.cdc` is the NonFungibleToken standard Flow smart contract.

`FungibleToken.cdc` is the FungibleToken standard on Flow.

`FlowToken.cdc` is the FlowToken smart contract.

`ExampleToken.cdc` is the Example smart contract.

`FUSD.cdc` is the FUSD smart contract.

`MetadataViews.cdc` holds the NFT metadata standard on Flow.

`Royalties.cdc` is a proposal of a royalty standard that we're using. The royalty standard is currently in flux, currently we're using the proposal as it looked like in early 2022. We will likely exercise the ability to upgrade contracts, once the standard is finalized.

`AsyncArtwork.cdc` implements the NonFungibleToken standard. It defines AsyncArtwork NFTs which can be either Master tokens or Control Tokens. This contract defines the minting of these tokens, updating control tokens, granting permissions to other users to update control tokens. 

`Blueprints.cdc` implements the NonFungibleToken standard. It defines Blueprint NFTs which are minted through the Blueprint mechanism. 

NFTs on AsyncArtwork.cdc and Blueprints.cdc adhere to the metadata standard from `MetadataViews.cdc`, and the royalty "standard" from `Royalties.cdc`. 

`NFTAuction.cdc` is an NFT marketplace based off the `NFTAuction.sol` [contract](https://github.com/avolabs-io/nft-auction) created by AvoLabs. It currently facilitates selling of `AsyncArtwork` and `Blueprints` NFTs.

## AsyncArtwork Design Decisions

It is important to note that we have opted to store the Metadata for each NFT in a mapping on contract. In many traditional Flow NFT projects, the Metadata would be stored on the NFT itself. However, Async Art has a unique use case, where they want to permission users to be able to UPDATE the metadata on OTHER USERS' NFTs. We considered giving these users capabilities to interfaces of collections for which they were permissioned to update NFTs but found many vulnerabilities in those designs with users moving around items in their storage, transferring their collections to other users, etc. Thus, for maximum safety, we are storing the NFT Metadata on-contract to ensure that permissioned users are always able to update NFTs even if the owner of the NFT moves their collection around in a hacky way, such that we loose track of its owner.

# Royalty Standard Implementation Design Decisions

The Royalty standard for NFTs on Flow exposes a single Fungible Token receiver capability per royalty recipient. The recommended path that this receiver is stored at is given in the `MetadataViews` contract. We opted to store a switchboard receiver for users at this path, which we set up for them at one of the 3 entry points: setting up the user to interact with AsyncArtwork (`transactions/setupAsyncUser.cdc`), setting up the user to interact with Blueprints (`transactions/Blueprints.cdc`), setting up the user to interact with NFTAuction (`transactions/setupMarketplaceClient.cdc`). We could have exposed the receiver to a FlowToken vault but opted for jumping the gun before a standardized switchboard is recommended by the Flow team because:
1. Once a standardized switchboard is recommended, swapping out the old switchboard for the new one at the generic path is the same amount of effort as switching out a FlowToken receiver for the recommended switchboard. Thus we may as well go with a switchboard that exists now.
2. We minimize royalties lost / sent to the platform as a backup with jumping the gun on the switchboard receiver.

However, the switchboard complicates things. One needs to add a currency as a supported type to the switchboard. As of May 1st, 2022, we instantiate the switchboard with support for FlowToken and FUSD. In the future, we can provide users a way to add currency support to their switchboard. If there are instances of payments failing due to unsupported currencies, marketplaces that operate well should extract the recipient address from the receiver capability, and attempt to search for the currency vault in the user account anyways. 

Thus, some potential work ahead: 
- create a transaction that swaps out the switchboard under /public/GenericFTReceiver for a standardized switchboard, for our users
- create transaction(s) that add support for given currencies to a user's switchboard

## NFTAuction Design Decisions

NFTAuction is based off an EVM smart contract created by AvoLabs here: https://github.com/avolabs-io/nft-auction/blob/master/contracts/NFTAuction.sol. 

Incoming...

## Blueprints Design Decisions

Incoming...
