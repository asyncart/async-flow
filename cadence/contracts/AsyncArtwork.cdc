import NonFungibleToken from "./NonFungibleToken.cdc"
import FungibleToken from "./FungibleToken.cdc"
import FlowToken from "./FlowToken.cdc"

pub contract AsyncArtwork: NonFungibleToken {
    pub var totalSupply: UInt64
    pub var collectionStoragePath: StoragePath 
    pub var collectionPublicPath: PublicPath
    pub var asyncIdStoragePath: StoragePath
    pub var asyncIdPrivateCapabilityPath: PrivatePath
    pub var asyncStateStoragePath: StoragePath
    pub var asyncStateAdminCapabilityPath: PrivatePath
    pub var asyncStateUserCapabilityPath: PrivatePath
    pub var asyncStatePublicCapabilityPath: PublicPath

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub struct ControlLever {
        pub var minValue: Int64
        pub var maxValue: Int64 
        pub var currentValue: Int64

        pub fun updateValue(_ newVal: Int64) {
            pre {
                newVal >= self.minValue
                newVal <= self.maxValue
            }
            self.currentValue = newVal
        }

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

    // The id in the NFT is also a pointer to it's metadata stored in AsyncState
    pub resource NFT: NonFungibleToken.INFT {
        pub let id: UInt64

        init (id: UInt64) {
            self.id = id
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

    // used to return data to the public, hiding the update functions
    pub struct interface NFTMetadataPublic {
        pub let id: UInt64
        pub let isMaster: Bool
        pub let layerCount: UInt64?
        pub var uri: String?
        pub var isUriLocked: Bool
        pub var platformFirstSalePercentage: UFix64
        pub var platformSecondSalePercentage: UFix64
        pub var tokenSoldOnce: Bool
        pub var numControlLevers: Int?
        pub var numRemainingUpdates: Int64?
        pub var uniqueTokenCreators: [Address]?
        pub var permissionedControllers: [Address]?
        pub fun getLeverValue(id: Int): Int64
    }

    pub struct NFTMetadata: NFTMetadataPublic {
        pub let id: UInt64

        // whether or not this NFT represents a master token or a control token
        pub let isMaster: Bool

        // The number of layers associated with a given master token
        pub let layerCount: UInt64?

        // Metadata URI
        pub var uri: String?

        // Whether or not the uri can still be updated
        pub var isUriLocked: Bool

        // The percentage of the sale value of the NFT that should be given to the AsyncArt platform when this NFT is sold for the first time
        pub var platformFirstSalePercentage: UFix64

        // The percentage of the sale value of the NFT that should be given to the AsyncArt platform when this NFT is sold subsequently to the first time
        pub var platformSecondSalePercentage: UFix64

        // Whether or not this NFT has been sold once on Async's marketplace
        pub var tokenSoldOnce: Bool

        // These fields only apply for control tokens
        // For master NFTs they will be nil or empty

        // The number of control levers that this control token has
        pub var numControlLevers: Int?
        
        // The number of allowed updates that users can enact on the control levers
        pub var numRemainingUpdates: Int64?

        // Control levers that can be used to tweak NFT metadata
        // needs to be private so that people can't change the metadata in the ControlTokens by calling updateValue
        access(self) let levers: {Int: ControlLever}

        // An array of addresses who receive a cut of the profits when this NFT is sold
        pub var uniqueTokenCreators: [Address]?

        // An array of addresses who are allowed to "control" (update the control levers on a control token, do nothing with a master token)
        pub var permissionedControllers: [Address]?

        pub fun getLeverValue(id: Int): Int64 {
            pre {
                self.levers[id] != nil : "Lever with id does not exist"
            }
            return self.levers[id]!.currentValue
        }

        pub fun updatePlatformSalesPercentages(_ platformFirstSalePercentage: UFix64,_ platformSecondSalePercentage: UFix64) {
            self.platformFirstSalePercentage = platformFirstSalePercentage
            self.platformSecondSalePercentage = platformSecondSalePercentage
        }

        pub fun setTokenSoldOnce() {
            pre {
                self.tokenSoldOnce == false : "tokenSoldOnce is already true"
            }
            self.tokenSoldOnce = true
        }

        pub fun updateUri(_ uri: String) {
            pre {
                !self.isUriLocked : "Cannot update uri -- locked"
            }
            self.uri = uri
        }

        pub fun lockUri() {
            pre {
                !self.isUriLocked : "Uri is already locked"
            }
            self.isUriLocked = true
        }

        pub fun initializeControlToken(
            uri: String,
            leverMinValues: [Int64],
            leverMaxValues: [Int64],
            leverStartValues: [Int64],
            numAllowedUpdates: Int64,
            uniqueTokenCreators: [Address]
        ) {
            pre {
                !self.isMaster : "Unexpectedly tried to initialize master token as control token"
                self.uri == nil : "Token uri non-nil on unitialized control token"
                self.levers.length == 0 : "Levers are non-empty on unitialized control token"
                self.numRemainingUpdates == nil : "Num remaining updates non-nil on unitialized control token"
                self.uniqueTokenCreators == nil : "Unqiue token creators non-nill on unitialized control token"
            }
            self.uri = uri
            self.uniqueTokenCreators = uniqueTokenCreators

            var i: Int = 0
            while i < leverStartValues.length {
                self.levers[i] = ControlLever(minValue: leverMinValues[i], maxValue: leverMaxValues[i], startValue: leverStartValues[i])
                i = i + 1
            }
        }

        pub fun initializeMasterToken(uri: String, uniqueTokenCreators: [Address]) {
            pre {
                self.isMaster : "Tried to intialize control token as master token"
                self.uri == nil : "Token uri is initialized on non-initialized master token"
                self.uniqueTokenCreators == nil : "uniqueTokenCreators initialized on non-intialized master token"
            }
            self.uri = uri
            self.uniqueTokenCreators = uniqueTokenCreators
        }

        pub fun updateControlTokenLevers(leverIds: [Int64], newLeverValues: [Int64]) {
            pre {
                !self.isMaster : "Cannot update levers on a master token"
                self.numRemainingUpdates != nil && self.numRemainingUpdates! > 0 : "No remaining updates for NFT"
            }

            var i: Int = 0
            while i < leverIds.length {
                if self.levers[i] == nil {
                    panic("Attempted to update invalid lever id")
                } else {
                    self.levers[i]!.updateValue(newLeverValues[i])
                }
                i = i + 1
            }

            self.numRemainingUpdates = self.numRemainingUpdates! - 1
        }

        init (
            id: UInt64,
            platformFirstSalePercentage: UFix64,
            platformSecondSalePercentage: UFix64,
            isMaster: Bool,
            layerCount: UInt64?,
            tokenUri: String?, 
            leverMinValues: [Int64]?,
            leverMaxValues: [Int64]?,
            leverStartValues: [Int64]?, 
            numAllowedUpdates: Int64?,
            uniqueTokenCreators: [Address]?,
            permissionedControllers: [Address]?
        ) {
            self.id = id
            self.platformFirstSalePercentage = platformFirstSalePercentage
            self.platformSecondSalePercentage = platformSecondSalePercentage
            self.isMaster = isMaster
            self.layerCount = layerCount
            self.uri = tokenUri
            self.isUriLocked = false
            self.numControlLevers = leverStartValues == nil ? (nil as Int?) : leverStartValues!.length
            self.numRemainingUpdates = numAllowedUpdates
            self.tokenSoldOnce = false
            self.uniqueTokenCreators = uniqueTokenCreators
            self.permissionedControllers = permissionedControllers
            self.levers = {}
            if leverMinValues != nil && leverMaxValues != nil && leverStartValues != nil {
                var i: Int = 0
                while i < leverStartValues!.length {
                    self.levers[i] = ControlLever(minValue: leverMinValues![i], maxValue: leverMaxValues![i], startValue: leverStartValues![i])
                    i = i + 1
                }
            }
        }
    }

    pub resource interface AsyncStateAdmin {
        pub var expectedTokenSupply: UInt64
        pub var defaultPlatformFirstSalePercentage: UFix64
        pub var defaultPlatformSecondSalePercentage: UFix64
        pub fun whitelistTokenForCreator(
            creatorAddress: Address,
            masterTokenId: UInt64,
            layerCount: UInt64,
            platformFirstSalePercentage: UFix64?,
            platformSecondSalePercentage: UFix64?
        )
        pub fun updatePlatformSalePercentageForToken(
            tokenId: UInt64,
            platformFirstSalePercentage: UFix64,
            platformSecondSalePercentage: UFix64
        )
        pub fun setTokenDidHaveFirstSaleForToken(tokenId: UInt64)
        pub fun setExpectedTokenSupply (newExpectedTokenSupply: UInt64)
        pub fun updateDefaultPlatformSalesPercentage (platformFirstSalePercentage: UFix64, platformSecondSalePercentage: UFix64)
        pub fun updateTokenURI(tokenId: UInt64, uri: String)
        pub fun lockTokenURI(tokenId: UInt64)
    }

    pub resource interface AsyncStateUser {
        pub fun setupControlToken(
            controlTokenId: UInt64,
            tokenUri: String, 
            leverMinValues: [Int64], 
            leverMaxValues: [Int64], 
            leverStartValues: [Int64],
            numAllowedUpdates: Int64,
            additionalCollaborators: [Address]
        ): @NFT

        pub fun mintArtwork(
            masterTokenId: UInt64,
            uri: String,
            controlTokenArtists: [Address],
            uniqueArtists: [Address]
        ): @NFT

        pub fun grantControlPermission(
            tokenId: UInt64,
            permissionedUser: Address
        )

        pub fun useControlToken(
            controlTokenId: UInt64,
            leverIds: [Int64],
            newLeverValues: [Int64],
            renderingTip: @FlowToken.Vault?
        )
    }

    pub resource interface AsyncStatePublic {
        pub fun getNFTMetadata(tokenId: UInt64): NFTMetadata{NFTMetadataPublic}
    }

    pub resource interface AsyncStateMarketplace {
        // certain functions that the marketplace contract should have access to
        // i.e. updating tokenSoldOnce
    }

    // The resource which manages all business logic related to AsyncArtwork
    pub resource AsyncState: AsyncStateAdmin, AsyncStateUser, AsyncStatePublic {
        // The number of tokens which have been allocated an id for minting
        pub var expectedTokenSupply: UInt64

        // A mapping of ids (from minted NFTs) to the metadata associated with them
        access(self) let nftIdsToMetadata: {UInt64 : NFTMetadata}

        // a default value for the first sales percentage assigned to an NFT when whitelisted
        // set to 5.0 if Async wanted a 5% cut
        pub var defaultPlatformFirstSalePercentage: UFix64

        // a default value for the second sales percentage assigned to an NFT when whitelisted
        // set to 5.0 if Async wanted a 5% cut
        pub var defaultPlatformSecondSalePercentage: UFix64

        // private capability to async id resource used to validate calls from this resource to user's AsyncCollections
        access(self) let asyncIdPrivateCapability: Capability<&AsyncId>

        // A capability to the FlowToken vault on this contract to recieve tips
        // We could also make a custom vault resource to be more robust
        pub var rendingTipVaultCapability: Capability<&FlowToken.Vault{FungibleToken.Receiver}>

        // returns whether or not a given sales percentage is a legal value
        access(self) fun isSalesPercentageValid(_ percentage: UFix64): Bool {
            return percentage < 100.0 && percentage >= 0.0
        }

        // Whitelist a master token for minting by an individual artist along with a certain number of component layers
        // TODO: remove masterTokenId and just work directly with expected token supply? i don't see why it needs to be passed in?
        pub fun whitelistTokenForCreator(
            creatorAddress: Address,
            masterTokenId: UInt64,
            layerCount: UInt64,
            platformFirstSalePercentage: UFix64?,
            platformSecondSalePercentage: UFix64?
        ) {
            pre {
                self.nftIdsToMetadata[masterTokenId] == nil : "NFT Metadata already exists at supplied masterTokenId"
                platformFirstSalePercentage == nil || self.isSalesPercentageValid(platformFirstSalePercentage!) : "Invalid platformFirstSalePercentage value"
                platformSecondSalePercentage == nil || self.isSalesPercentageValid(platformSecondSalePercentage!) : "Invalid platformSecondSalePercentage value"
            }
            let creatorPublicAccount = getAccount(creatorAddress)
            //let creatorAsyncCollectionGateway = creatorPublicAccount.getCapability(/public/CollectionAsyncGateway).borrow() ?? panic("Address specified does not have public capability to AsyncCollectionGateway")
            // creatorAsyncCollectionGateway.reserveMasterMint(id: masterTokenId, asyncIdCap: self.asyncIdPrivateCapability)

            // establish basic metadata for master token
            self.nftIdsToMetadata[masterTokenId] = NFTMetadata(
                id: masterTokenId,
                platformFirstSalePercentage: platformFirstSalePercentage == nil ? self.defaultPlatformFirstSalePercentage : platformFirstSalePercentage!,
                platformSecondSalePercentage: platformSecondSalePercentage == nil ? self.defaultPlatformSecondSalePercentage : platformSecondSalePercentage!,
                isMaster: true,
                layerCount: layerCount,
                tokenUri: nil, 
                leverMinValues: nil,
                leverMaxValues: nil,
                leverStartValues: nil, 
                numAllowedUpdates: nil,
                uniqueTokenCreators: nil,
                permissionedControllers: nil
            )

            // establish basic metadata for control tokens
            var layerIndex = masterTokenId + 1
            while layerIndex <= masterTokenId + layerCount {
                self.nftIdsToMetadata[layerIndex] = NFTMetadata(
                    id: layerIndex,
                    platformFirstSalePercentage: platformFirstSalePercentage == nil ? self.defaultPlatformFirstSalePercentage : platformFirstSalePercentage!,
                    platformSecondSalePercentage: platformSecondSalePercentage == nil ? self.defaultPlatformSecondSalePercentage : platformSecondSalePercentage!,
                    isMaster: false,
                    layerCount: nil,
                    tokenUri: nil, 
                    leverMinValues: nil,
                    leverMaxValues: nil,
                    leverStartValues: nil, 
                    numAllowedUpdates: nil,
                    uniqueTokenCreators: nil,
                    permissionedControllers: nil
                )

                layerIndex = layerIndex + 1
            }
        }

        // Admin can update the platform sales percentages for a given token
        pub fun updatePlatformSalePercentageForToken(
            tokenId: UInt64,
            platformFirstSalePercentage: UFix64,
            platformSecondSalePercentage: UFix64
        ) {
            pre {
                self.isSalesPercentageValid(platformFirstSalePercentage) : "Cannot update. Invalid platformFirstSalePercentage value"
                self.isSalesPercentageValid(platformSecondSalePercentage) : "Cannot update. Invalid platformSecondSalePercentage value"
                self.nftIdsToMetadata[tokenId] != nil : "Token doesn't exist"
            }

            self.nftIdsToMetadata[tokenId]!.updatePlatformSalesPercentages(platformFirstSalePercentage, platformSecondSalePercentage)
        }

        // Admin can set the "tokenSoldOnce" flag on a piece of metadata manually
        pub fun setTokenDidHaveFirstSaleForToken(tokenId: UInt64) {
            pre {
                self.nftIdsToMetadata[tokenId] != nil : "TokenId does not exist"
            }
            self.nftIdsToMetadata[tokenId]!.setTokenSoldOnce()
        }

        // Admin can update the expectedTokenSupply state variable
        // We may not need this if this is only used to increment the expected token supply for whitelistTokenForCreator
        // if there are other reasons why we would want this value to change (in a more custom way) then we can leave this
        pub fun setExpectedTokenSupply (newExpectedTokenSupply: UInt64) {
            pre {
                newExpectedTokenSupply >= 0 : "Unexpectedly found negative value for expected token supply"
            }
            self.expectedTokenSupply = newExpectedTokenSupply
        }

        // Admin can update the default sales percentages attached to new tokens
        pub fun updateDefaultPlatformSalesPercentage (
            platformFirstSalePercentage: UFix64,
            platformSecondSalePercentage: UFix64
        ) {
            pre {
                self.isSalesPercentageValid(platformFirstSalePercentage) : "Invalid new default platformFirstSalePercentage"
                self.isSalesPercentageValid(platformSecondSalePercentage) : "Invalid new default platformSecondSalePercentage"
            }
            self.defaultPlatformFirstSalePercentage = platformFirstSalePercentage
            self.defaultPlatformSecondSalePercentage = platformSecondSalePercentage
        }

        // Admin can update the URI associated with a specific token
        pub fun updateTokenURI(
            tokenId: UInt64,
            uri: String
        ) {
            pre {
                self.nftIdsToMetadata[tokenId] != nil : "Token with tokenId does not exist in metadata mapping"
            }
            self.nftIdsToMetadata[tokenId]!.updateUri(uri)
        }

        // Admin can lock the token uri
        pub fun lockTokenURI(
            tokenId: UInt64
        ) {
            pre {
                self.nftIdsToMetadata[tokenId] != nil : "Token with tokenId does not exist in metadata mapping"
            }
            self.nftIdsToMetadata[tokenId]!.lockUri()
        }

        // Mint Control Token NFT once one is already allocated to you via MintArtwork
        pub fun setupControlToken(
            controlTokenId: UInt64,
            tokenUri: String,
            leverMinValues: [Int64], 
            leverMaxValues: [Int64], 
            leverStartValues: [Int64],
            numAllowedUpdates: Int64,
            additionalCollaborators: [Address]
        ): @NFT {
            pre {
                leverMaxValues.length <= 500 : "Too many control levers."
                leverMaxValues.length == leverMinValues.length && leverStartValues.length == leverMaxValues.length : "Length of lever arrays do not match"
                numAllowedUpdates == -1 || numAllowedUpdates > 0 : "Invalid num allowed updates"
                additionalCollaborators.length <= 50 : "Too many collaborators"
                self.nftIdsToMetadata[controlTokenId] != nil : "controlTokenId does not exist in metadata mapping"
            }

            self.nftIdsToMetadata[controlTokenId]!.initializeControlToken(
                uri: tokenUri,
                leverMinValues: leverMinValues,
                leverMaxValues: leverMaxValues,
                leverStartValues: leverStartValues,
                numAllowedUpdates: numAllowedUpdates,
                uniqueTokenCreators: additionalCollaborators
            )

            // Mint NFT (with id: controlTokenId)
            let controlTokenNFT <- create NFT(id: controlTokenId)

            return <- controlTokenNFT
        }

        // Mint Master Token NFT already allocated to you via WhitelistTokenForCreator
        pub fun mintArtwork(
            masterTokenId: UInt64, 
            uri: String,
            controlTokenArtists: [Address],
            uniqueArtists: [Address]
        ): @NFT {
            pre {
                self.nftIdsToMetadata[masterTokenId] != nil : "masterTokenId not associated with an allocated tokenId"
                self.nftIdsToMetadata[masterTokenId]!.isMaster == true : "masterTokenId not associated with Master NFT"
            }

            self.nftIdsToMetadata[masterTokenId]!.initializeMasterToken(uri: uri, uniqueTokenCreators: uniqueArtists)

            let masterTokenNFT <- create NFT(id: masterTokenId)

            var controlTokenIndex: UInt64 = masterTokenId + 1
            for artist in controlTokenArtists {
                let artistPublicAccount = getAccount(artist)
                //let artistAsyncGateway = artistPublicAccount.getCapability(/public/CollectionAsyncGateway).borrow() ?? panic("Failed to borrow async gateway capability")
                // artistAsyncGateway.reserveControlMint(id: controlTokenIndex, asyncIdCap: self.asyncIdPrivateCapability)
                controlTokenIndex = controlTokenIndex + 1
            }

            return <- masterTokenNFT
        }

        // Public getter for the metadata of any token
        pub fun getNFTMetadata(tokenId: UInt64): NFTMetadata{NFTMetadataPublic} {
            pre {
                self.nftIdsToMetadata[tokenId] != nil : "token id does not exist in metadata mapping"
            }
            let publicMetadata: NFTMetadata{NFTMetadataPublic} = self.nftIdsToMetadata[tokenId]!
            return publicMetadata
        }

        // Async Users can grant another Async User control over their NFT
        pub fun grantControlPermission(tokenId: UInt64, permissionedUser: Address) {
            pre {
                self.nftIdsToMetadata[tokenId] != nil : "Token id not allocated"
            }

            let permissionedUserPublicAccount = getAccount(permissionedUser)
            // let creatorAsyncGateway = permissionedUserPublicAccount.getCapability(/public/CollectionAsyncGateway).borrow() ?? panic("Address specified does not have public capability to AsyncCollection")
            // creatorAsyncGateway.grantPermission(id: tokenId, grant: true, self.asyncIdPrivateCapability)
        }

        // Async Users can update the control levers for NFTs they own
        pub fun useControlToken(
            controlTokenId: UInt64,
            leverIds: [Int64],
            newLeverValues: [Int64],
            renderingTip: @FlowToken.Vault?
        ) {
            pre {
                self.nftIdsToMetadata[controlTokenId] != nil : "Control token id not allocated"
                leverIds.length == newLeverValues.length : "Lengths of lever arrays are different"
                self.rendingTipVaultCapability.check() : "Cannot borrow reference to tip vault"
            }

            if renderingTip != nil {
                self.rendingTipVaultCapability.borrow()!.deposit(from: <- renderingTip!)
            }

            self.nftIdsToMetadata[controlTokenId]!.updateControlTokenLevers(leverIds: leverIds, newLeverValues: newLeverValues)
        }

        init(_ rendingTipVaultCapability: Capability<&FlowToken.Vault{FungibleToken.Receiver}>, _ asyncIdPrivateCapability: Capability<&AsyncId>) {
            pre {
                rendingTipVaultCapability.check() : "Cannot borrow renderingTipVaultCapability"
                asyncIdPrivateCapability.check() : "Cannot borrow capability to asyncId"
            }
            self.asyncIdPrivateCapability = asyncIdPrivateCapability
            self.rendingTipVaultCapability = rendingTipVaultCapability
            self.expectedTokenSupply = 0
            self.nftIdsToMetadata = {}
            self.defaultPlatformFirstSalePercentage = 5.0
            self.defaultPlatformSecondSalePercentage = 1.0
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
        self.asyncStateStoragePath = /storage/AsyncArtworkStateStorage
        self.asyncStateAdminCapabilityPath = /private/AsyncArtworkStateAdmin
        self.asyncStateUserCapabilityPath = /private/AsyncArtworkStateUser
        self.asyncStatePublicCapabilityPath = /public/AsyncArtworkStatePublic

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
        self.account.link<&AsyncId>(
            self.asyncIdPrivateCapabilityPath,
            target: self.asyncIdStoragePath
        )

        let rendingTipVaultCapability = self.account.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
        let asyncIdPrivateCapability = self.account.getCapability<&AsyncId>(self.asyncIdPrivateCapabilityPath)

        let asyncState <- create AsyncState(rendingTipVaultCapability, asyncIdPrivateCapability)
        self.account.save(<- asyncState, to: self.asyncStateStoragePath)

        // link capability to admin resource to deployment account
        self.account.link<&AsyncState{AsyncStateAdmin}>(
            self.asyncStateAdminCapabilityPath,
            target: self.asyncStateStoragePath
        )

        // link capability to user resource to deployment account
        self.account.link<&AsyncState{AsyncStateUser}>(
            self.asyncStateUserCapabilityPath,
            target: self.asyncStateStoragePath
        )

        emit ContractInitialized()
	}
}