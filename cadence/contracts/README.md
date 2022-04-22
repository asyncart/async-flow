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

## NFTAuction Design Decisions

## Blueprints Design Decisions