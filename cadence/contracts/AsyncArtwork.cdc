import NonFungibleToken from "./NonFungibleToken.cdc"

pub contract AsyncArtwork: NonFungibleToken {
    pub var totalSupply: UInt64
    pub var collectionStoragePath: StoragePath 
    pub var collectionPublicPath: PublicPath
    pub var asyncIdStoragePath: StoragePath
    pub var asyncIdPrivateCapabilityPath: PrivatePath

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub struct ControlLever {
        pub var minValue: Int64
        pub var maxValue: Int64 
        pub var currentValue: Int64

        init(minValue: Int64, maxValue: Int64, startValue: Int64) {
            pre {
                maxValue > minValue : "Max value must >= min"
                startValue >= minValue && startValue <= maxValue : "Invalid start value"
            }
            self.minValue = minValue
            self.maxValue = maxValue
            self.currentValue = startValue
        }
    }

    // this is ControlToken
    pub resource NFT: NonFungibleToken.INFT {
        pub let id: UInt64
        pub var numControlLevers: Int
        pub var numRemainingUpdates: Int64
        pub var levers: {Int: ControlLever}
        pub var uri: String

        init (
            initID: UInt64,
            tokenUri: String, 
            leverMinValues: [Int64],
            leverMaxValues: [Int64],
            leverStartValues: [Int64], 
            numAllowedUpdates: Int64
        ) {
            self.id = initID
            self.numControlLevers = leverStartValues.length
            self.numRemainingUpdates = numAllowedUpdates
            self.levers = {}
            var i: Int = 0;
            while i < leverStartValues.length {
                self.levers[i] = ControlLever(minValue: leverMinValues[i], maxValue: leverMaxValues[i], startValue: leverStartValues[i])
                i = i + 1
            }
            self.uri = tokenUri
        }
    }

    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
        }

        // withdraw removes an NFT from the collection and moves it to the caller
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        // deposit takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @AsyncArtwork.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        // getIDs returns an array of the IDs that are in the collection
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowNFT gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return &self.ownedNFTs[id] as &NonFungibleToken.NFT
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    // public function that anyone can call to create a new empty collection
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }


    pub struct NFTMetadata {

    }

    // The resource which manages all business logic related to AsyncArtwork
    pub resource AsyncState {
        // The number of tokens which have been allocated an id for minting
        pub var expectedTokenSupply: UInt64

        // A mapping of ids (from minted NFTs) to the metadata associated with them
        pub let nftIdsToMetadata: {UInt64 : NFTMetadata}

        // a default value for the first sales percentage assigned to an NFT when whitelisted
        // set to 0.05 if Async wanted a 5% cut
        pub var defaultPlatformFirstSalePercentage: UFix64

        // a default value for the second sales percentage assigned to an NFT when whitelisted
        // set to 0.05 if Async wanted a 5% cut
        pub var defaultPlatformSecondSalePercentage: UFix64

        // Whitelist a master token for minting by an individual artist along with a certain
        // number of component layers
        // ADMIN ONLY
        pub fun whitelistTokenForCreator(
            creatorAddress: Address,
            masterTokenId: UInt64,
            layerCount: UInt64,
            platformFirstSalePercentage: UFix64?,
            platformSecondSalePercentage: UFix64?
        ) {

        }

        // update the platform sales percentages for a given token
        // ADMIN ONLY
        pub fun updatePlatformSalePercentageForToken(
            tokenId: UInt64,
            platformFirstSalePercentage: UFix64,
            platformSecondSalePercentage: UFix64
        ) {

        }

        // set a flag on the NFT metadata
        // ADMIN only
        pub fun setTokenDidHaveFirstSaleForToken(
            tokenId: UInt64
        ) {

        }

        // change var on state
        // ADMIN only
        pub fun setExpectedTokenSupply(
            newExpectedTokenSupply: UInt64
        ) {

        }

        // change var on statre
        // ADMIN only
        pub fun updateDefaultPlatformSalesPercentage (
            platformFirstSalePercentage: UFix64?,
            platformSecondSalePercentage: UFix64?
        ) {

        }

        // update the metadata in a specific way for an nft
        // ADMIN only
        pub fun updateTokenURI(
            tokenId: UInt64,
            uri: String
        ) {

        }

        // update the metadata in a specific way for an nft
        // ADMIN only
        pub fun lockTokenURI(
            tokenId: UInt64
        ) {

        }

        // Mint control token when permitted to do so via mintArtwork
        // callable by anyone
        pub fun setupControlToken(
            controlTokenRecipient: &{NonFungibleToken.CollectionPublic}, 
            tokenUri: String, 
            leverMinValues: [Int64], 
            leverMaxValues: [Int64], 
            leverStartValues: [Int64],
            numAllowedUpdates: Int64,
            additionalCollaborators: [Address]
        ) {
            pre {
                leverMaxValues.length <= 500 : "Too many control levers."
                leverMaxValues.length == leverMinValues.length && leverStartValues.length == leverMaxValues.length : "Length of lever arrays do not match"
                numAllowedUpdates == -1 || numAllowedUpdates > 0 : "Invalid num allowed updates"
                additionalCollaborators.length <= 50 : "Too many collaborators"
            }

            // create a new NFT
            var newControlToken <- create NFT(
                initID: AsyncArtwork.totalSupply, 
                tokenUri: tokenUri,
                leverMinValues: leverMinValues,
                leverMaxValues: leverMaxValues,
                leverStartValues: leverStartValues,
                numAllowedUpdates: numAllowedUpdates
            )

            // deposit it in the recipient's account using their reference
            recipient.deposit(token: <- newControlToken)

            AsyncArtwork.totalSupply = AsyncArtwork.totalSupply + (1 as UInt64)
        }

        // aka mint master token NFT
        // callable by anyone
        pub fun mintArtwork(
            masterTokenId: UInt64,
            uri: String,
            controlTokenArtists: [Address],
            uniqueArtists: [Address]
        ) {

        }

        // callable by anyone
        pub fun getNFTMetadata(
            tokenId: UInt64
        ) {

        }

        // grant control permission
        // callable by anyone
        pub fun grantControlPermission(
            tokenId: UInt64,
            permissionedUser: Address
        ) {

        }

        // basically update NFT Metadata
        pub fun useControlToken(
            controlTokenId: UInt64,
            leverIds: [Int64],
            newLeverValues: [Int64]
        ) {

        }
    }

    // Resource used to control access to public functions
    pub resource AsyncId {
        pub let id: UInt64

        init() {
            self.id = 42
        }
    }

	init() {
        self.collectionStoragePath = /storage/AsyncArtworkNFTCollection
        self.collectionPublicPath = /public/AsyncArtworkCollection
        self.asyncIdStoragePath = /storage/AsyncArtworkId
        self.asyncIdPrivateCapabilityPath = /private/AsyncArtworkId

        // Initialize the total supply
        self.totalSupply = 0

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.save(<-collection, to: self.collectionStoragePath)

        // create a public capability for the collection
        self.account.link<&{NonFungibleToken.CollectionPublic}>(
            self.collectionPublicPath,
            target: self.collectionStoragePath
        )

        // Create AsyncId resource and have store it in deployer account storage with a private capability
        let asyncId <- create AsyncId()
        self.account.save(<-asyncId, to: self.asyncIdStoragePath)
        self.account.link<&AsyncArtworkId>(
            self.asyncIdPrivateCapabilityPath,
            target: self.asyncIdStoragePath
        )

        emit ContractInitialized()
	}
}
 