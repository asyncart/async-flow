# Contracts

There are four Cadence smart contracts in this folder.

`NonFungibleToken.cdc` is the NonFungibleToken standard Flow smart contract.

`AsyncArtwork.cdc` implements this NonFungibleToken standard. It defines AsyncArtwork NFTs which can be either Master tokens or Control Tokens. This contract defines the minting of these tokens, updating control tokens, granting permissions to other users to update control tokens.

`FungibleToken.cdc` the FungibleToken standard on Flow.

`FlowToken.cdc` the FlowToken smart contract.

## Design Decisions

It is important to note that we have opted to store the Metadata for each NFT in a mapping on contract. In many traditional Flow NFT projects, the Metadata would be stored on the NFT itself. However, Async Art has a unique use case, where they want to permission users to be able to UPDATE the metadata on OTHER USERS' NFTs. We considered giving these users capabilities to interfaces of collections for which they were permissioned to update NFTs but found many vulnerabilities in those designs with users moving around items in their storage, transferring their collections to other users, etc. Thus, for maximum safety, we are storing the NFT Metadata on-contract to ensure that permissioned users are always able to update NFTs even if the owner of the NFT moves their collection around in a hacky way, such that we loose track of its owner.