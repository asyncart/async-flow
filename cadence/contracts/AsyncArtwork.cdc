import NonFungibleToken from "./NonFungibleToken.cdc"
import FungibleToken from "./FungibleToken.cdc"
import FlowToken from "./FlowToken.cdc"

pub contract AsyncArtwork: NonFungibleToken {
    pub var totalSupply: UInt64
    pub let collectionStoragePath: StoragePath 
    pub let collectionPrivatePath: PrivatePath
    pub let collectionPublicPath: PublicPath
    pub let adminStoragePath: StoragePath
    pub let adminPrivatePath: PrivatePath
    pub let minterStoragePath: StoragePath
    pub let minterPrivatePath: PrivatePath

    // The number of tokens which have been allocated an id for minting
    pub var expectedTokenSupply: UInt64

    // A mapping of ids (from minted NFTs) to the metadata associated with them
    access(self) let metadata: {UInt64 : NFTMetadata}

    // a default value for the first sales percentage assigned to an NFT when whitelisted
    // set to 5.0 if Async wanted a 5% cut
    pub var defaultPlatformFirstSalePercentage: UFix64

    // a default value for the second sales percentage assigned to an NFT when whitelisted
    // set to 5.0 if Async wanted a 5% cut
    pub var defaultPlatformSecondSalePercentage: UFix64

    // Second sale percentage for artists platform wide
    pub var artistSecondSalePercentage: UFix64

    access(self) let tipVault: @FungibleToken.Vault

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    
    pub event PermissionUpdated(
        tokenId: UInt64,
        tokenOwner: Address,
        permissioned: Address,
        granted: Bool
    )

    pub event CreatorWhitelisted(
        tokenId: UInt64,
        layerCount: UInt64,
        creator: Address
    )

    pub event PlatformSalePercentageUpdated(
        tokenId: UInt64,
        platformFirstPercentage: UFix64,
        platformSecondPercentage: UFix64
    )

    pub event DefaultPlatformSalePercentageUpdated(
        defaultPlatformFirstSalePercentage: UFix64,
        defaultPlatformSecondSalePercentage: UFix64
    )

    pub event ArtistSecondSalePercentUpdated(artistSecondPercentage: UFix64)

    pub event TokenSoldOnce(
        tokenId: UInt64
    )

    pub event ControlLeverUpdated(
        tokenId: UInt64,
        priorityTip: UFix64,
        numRemainingUpdates: Int64,
        leverIds: [UInt64],
        previousValues: [Int64],
        updatedValues: [Int64]
    )

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

    pub resource interface ViewResolver {
        pub fun getViews() : [Type]
        pub fun resolveView(_ view:Type): AnyStruct?    
    }

    // The id in the NFT is also a pointer to it's metadata stored on contract
    pub resource NFT: NonFungibleToken.INFT, ViewResolver {
        pub let id: UInt64

        pub fun getViews() : [Type] {
            return [
                Type<String>(),
                Type<{UInt64: ControlLever}>(),
                Type<[Address]>()
            ]
        }

        pub fun resolveView(_ type: Type): AnyStruct {
            let metadata = AsyncArtwork.getNFTMetadata(tokenId: self.id)

            if type == Type<String>() {
                return metadata.uri
            } else if type == Type<{UInt64: ControlLever}>() {
                return metadata.getLevers()
            } else if type == Type<[Address]>() {
                return metadata.getUniqueTokenCreators()
            } else {
                return nil
            }
        }

        init (id: UInt64) {
            self.id = id
        }
    }

    pub resource Auth {}

    // Private
    pub resource interface AsyncCollectionPrivate {
        pub fun mintMasterToken(
            id: UInt64, 
            artworkUri: String, 
            controlTokenArtists: [Address], 
            uniqueArtists: [Address]
        ) 

        pub fun mintControlToken(
            id: UInt64,
            tokenUri: String, 
            leverMinValues: [Int64], 
            leverMaxValues: [Int64], 
            leverStartValues: [Int64],
            numAllowedUpdates: Int64,
            additionalCollaborators: [Address]
        )

        pub fun useControlToken(
            id: UInt64, 
            leverIds: [UInt64], 
            newLeverValues: [Int64], 
            renderingTip: @FungibleToken.Vault?
        )

        pub fun grantControlPermission(id: UInt64, permissionedUser: Address, grant: Bool)
    }

    // Public
    pub resource interface AsyncCollectionPublic {
        pub fun reserveMasterMint(id: UInt64, layerCount: UInt64, auth: @AsyncArtwork.Auth)

        pub fun reserveControlMint(id: UInt64, auth: @AsyncArtwork.Auth)

        pub fun updateControlPermission(id: UInt64, grant: Bool, auth: @AsyncArtwork.Auth)

        pub fun getMasterMintReservation(): {UInt64: UInt64}

        pub fun getControlMintReservation(): {UInt64: UInt64}
        
        pub fun getControlUpdate(): {UInt64: UInt64}
    }

    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, AsyncCollectionPublic, AsyncCollectionPrivate {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        // used to track what master tokens a user can mint
        // a mapping of mintable masterTokenIds -> their layer counts
        access(self) let masterMintReservation: {UInt64: UInt64}

        // used to track what control tokens a user can mint
        // a mapping of mintable controlTokenIds -> themselves (a set, but Cadence doesn't have sets)
        access(self) let controlMintReservation: {UInt64: UInt64}

        // used to track what control tokens a user can update
        // a mapping of updatable controlTokenIds -> themselves (a set, but Cadence doesn't have sets)
        access(self) let controlUpdate: {UInt64: UInt64}

        init () {
            self.ownedNFTs <- {}
            self.masterMintReservation = {}
            self.controlMintReservation = {}
            self.controlUpdate = {}
        }

        // =============================
        // Getters
        // =============================

        pub fun getMasterMintReservation(): {UInt64: UInt64} {
            return self.masterMintReservation
        }

        pub fun getControlMintReservation(): {UInt64: UInt64} {
            return self.controlMintReservation
        }

        pub fun getControlUpdate(): {UInt64: UInt64} {
            return self.controlUpdate
        }

        // =============================
        // AsyncCollectionPrivate interface
        // =============================

        pub fun mintMasterToken(
            id: UInt64, 
            artworkUri: String, 
            controlTokenArtists: [Address], 
            uniqueArtists: [Address]
        ) {
            pre {
                AsyncArtwork.metadata.containsKey(id) : "id not associated with any metadata"
                AsyncArtwork.metadata[id]!.isMaster == true : "Metadata for token id is set for a control token"
                self.masterMintReservation.containsKey(id) : "Not authorized to mint"
                self.masterMintReservation[id] == UInt64(controlTokenArtists.length) : "Layer count does not match control token artist length"
            }

            post {
                !self.masterMintReservation.containsKey(id) : "Reservation not removed after mint"
                self.ownedNFTs.containsKey(id) : "Did not receive minted token"
            }
            
            let owner = self.owner ?? panic("No current owner")

            AsyncArtwork.metadata[id]!.initializeMasterToken(uri: artworkUri, uniqueTokenCreators: uniqueArtists, owner: owner.address)

            let masterTokenNFT <- create NFT(id: id)

            AsyncArtwork.totalSupply = AsyncArtwork.totalSupply + 1

            var controlTokenIndex: UInt64 = id + 1
            for artist in controlTokenArtists {
                let auth <- create AsyncArtwork.Auth()
                let artistPublicAccount = getAccount(artist)
                let artistPublicCollection = artistPublicAccount.getCapability<&Collection{AsyncCollectionPublic}>(AsyncArtwork.collectionPublicPath).borrow() ?? panic("Failed to borrow async public capability")
                artistPublicCollection.reserveControlMint(id: controlTokenIndex, auth: <- auth)
                controlTokenIndex = controlTokenIndex + 1
            }

            self.deposit(token: <- masterTokenNFT)

            self.masterMintReservation.remove(key: id)
        }

        pub fun mintControlToken(
            id: UInt64,
            tokenUri: String, 
            leverMinValues: [Int64], 
            leverMaxValues: [Int64], 
            leverStartValues: [Int64],
            numAllowedUpdates: Int64,
            additionalCollaborators: [Address]
        ) {
            pre {
                AsyncArtwork.metadata.containsKey(id) : "Token id is not associated with any metadata"
                self.controlMintReservation.containsKey(id) : "Not authorized to mint"
                leverMinValues.length <= 500 : "Too many control levers"
                additionalCollaborators.length <= 50 : "Too many collaborators"
                numAllowedUpdates == -1 || numAllowedUpdates > 0 : "Invalid allowed updates"
                leverMinValues.length == leverMaxValues.length && leverMaxValues.length == leverStartValues.length : "Values array mismatch"
            }

            post {
                !self.controlMintReservation.containsKey(id) : "Reservation not removed after mint"
                self.ownedNFTs.containsKey(id) : "Did not receive minted token"
            }

            let owner = self.owner ?? panic("No current owner")

            AsyncArtwork.metadata[id]!.initializeControlToken(
                uri: tokenUri,
                leverMinValues: leverMinValues,
                leverMaxValues: leverMaxValues,
                leverStartValues: leverStartValues,
                numAllowedUpdates: numAllowedUpdates,
                uniqueTokenCreators: additionalCollaborators,
                owner: owner.address
            )

            let controlTokenNFT <- create NFT(id: id)
            AsyncArtwork.totalSupply = AsyncArtwork.totalSupply + 1

            self.deposit(token: <- controlTokenNFT)

            self.controlMintReservation.remove(key: id)
        }

        pub fun useControlToken(
            id: UInt64, 
            leverIds: [UInt64], 
            newLeverValues: [Int64], 
            renderingTip: @FungibleToken.Vault?
        ) {
            pre {
                self.ownedNFTs.containsKey(id) || self.controlUpdate.containsKey(id) : "Not authorized to use control token"
                AsyncArtwork.metadata.containsKey(id) : "Control token id not allocated"
                leverIds.length == newLeverValues.length : "Lengths of lever arrays are different"
            }

            var tip: UFix64 = 0.0

            let oldLevers: {UInt64: AsyncArtwork.ControlLever} = AsyncArtwork.metadata[id]!.getLevers()
            let previousValues: [Int64] = []

            for leverId in leverIds {
                let lever: AsyncArtwork.ControlLever = oldLevers[leverId] ?? panic("Could not find control lever for an id")
                previousValues.append(lever.currentValue)
            }

            if renderingTip != nil {
                let oldBalance: UFix64 = AsyncArtwork.getTipBalance()
                AsyncArtwork.tipVault.deposit(from: <- renderingTip!)
                tip = AsyncArtwork.getTipBalance() - oldBalance
            } else {
                destroy renderingTip
            }

            let newValues: [Int64] = AsyncArtwork.metadata[id]!.updateControlTokenLevers(leverIds: leverIds, newLeverValues: newLeverValues)

            emit ControlLeverUpdated(
                tokenId: id,
                priorityTip: tip,
                numRemainingUpdates: AsyncArtwork.metadata[id]!.numRemainingUpdates!,
                leverIds: leverIds,
                previousValues: previousValues,
                updatedValues: newValues
            )
        }

        // Grant permissions to another user to update the levels on your control token?
        pub fun grantControlPermission(id: UInt64, permissionedUser: Address, grant: Bool) {
            pre {
                self.ownedNFTs.containsKey(id) : "Not authorized to grant permissions for this token"
                AsyncArtwork.metadata.containsKey(id) : "Token metadata does not exist"
                !AsyncArtwork.metadata[id]!.isMaster : "Cannot grant permissions for master token"
            }

            let permissionedUserPublicAccount = getAccount(permissionedUser)
            let permissionedUserAsyncCollection = permissionedUserPublicAccount.getCapability<&Collection{AsyncCollectionPublic}>(AsyncArtwork.collectionPublicPath).borrow() ?? panic("Address specified does not have public capability to AsyncCollection")
            permissionedUserAsyncCollection.updateControlPermission(id: id, grant: grant, auth: <- create AsyncArtwork.Auth())
            emit PermissionUpdated(
                tokenId: id, 
                tokenOwner: self.owner?.address!, 
                permissioned: permissionedUser, 
                granted: grant
            )
        }

        // =============================
        // AsyncCollectionPublic interface
        // =============================

        pub fun updateControlPermission(id: UInt64, grant: Bool, auth: @AsyncArtwork.Auth) {
            pre {
                AsyncArtwork.metadata.containsKey(id) : "Metadata for this token id does not exist"
                !self.controlUpdate.containsKey(id) == grant : "Current state of permission for token matches requested state"
            }
            if grant {
                self.controlUpdate.insert(key: id, 0)
            } else {
                self.controlUpdate.remove(key: id)
            }

            destroy auth
        }

        pub fun reserveMasterMint(id: UInt64, layerCount: UInt64, auth: @AsyncArtwork.Auth) {
            pre {
                !self.masterMintReservation.containsKey(id) : "Reservation already added"
            }

            post {
                self.masterMintReservation.containsKey(id) : "Reservation not added"
            }

            self.masterMintReservation.insert(key: id, layerCount)
            destroy auth
        }

        pub fun reserveControlMint(id: UInt64, auth: @AsyncArtwork.Auth) {
            pre {
                !self.controlMintReservation.containsKey(id) : "Reservation already added"
            }

            post {
                self.controlMintReservation.containsKey(id) : "Reservation not added"
            }

            self.controlMintReservation.insert(key: id, 0)
            destroy auth
        }

        // =============================
        // NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic interfaces
        // =============================

        // withdraw removes an NFT from the collection and moves it to the caller
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        // deposit takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        pub fun deposit(token: @NonFungibleToken.NFT) {
            pre {
                AsyncArtwork.metadata.containsKey(token.id) : "Metadata for token doesn't exist"
            }

            let token <- token as! @AsyncArtwork.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            let owner = self.owner ?? panic("No current owner")
            AsyncArtwork.metadata[id]!.updateOwner(owner.address)

            emit Deposit(id: id, to: owner.address)

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

    // returns whether or not a given sales percentage is a legal value
    access(self) fun isSalesPercentageValid(_ percentage: UFix64): Bool {
        return percentage < 100.0 && percentage >= 0.0
    }

    // minter and platform are decoupled
    pub resource Minter {
		// Whitelist a master token for minting by an individual artist along with a certain number of component layers
        pub fun whitelistTokenForCreator(
            creatorAddress: Address,
            masterTokenId: UInt64,
            layerCount: UInt64,
            platformFirstSalePercentage: UFix64?,
            platformSecondSalePercentage: UFix64?
        ) {
            pre {
                masterTokenId == AsyncArtwork.expectedTokenSupply + 1 : "Master token id must be the same as the expectedTokenSupply"
                AsyncArtwork.metadata[masterTokenId] == nil : "NFT Metadata already exists at supplied masterTokenId"
                platformFirstSalePercentage == nil || AsyncArtwork.isSalesPercentageValid(platformFirstSalePercentage!) : "Invalid platformFirstSalePercentage value"
                platformSecondSalePercentage == nil || AsyncArtwork.isSalesPercentageValid(platformSecondSalePercentage!) : "Invalid platformSecondSalePercentage value"
            }

            let creatorPublicAccount = getAccount(creatorAddress)
            let creatorAsyncPublicCollection = creatorPublicAccount.getCapability<&Collection{AsyncCollectionPublic}>(AsyncArtwork.collectionPublicPath).borrow() ?? panic("Address specified does not have public capability to AsyncCollectionPublic")
            creatorAsyncPublicCollection.reserveMasterMint(id: masterTokenId, layerCount: layerCount, auth: <- create AsyncArtwork.Auth())

            // establish basic metadata for master token
            AsyncArtwork.metadata[masterTokenId] = NFTMetadata(
                id: masterTokenId,
                platformFirstSalePercentage: platformFirstSalePercentage == nil ? AsyncArtwork.defaultPlatformFirstSalePercentage : platformFirstSalePercentage!,
                platformSecondSalePercentage: platformSecondSalePercentage == nil ? AsyncArtwork.defaultPlatformSecondSalePercentage : platformSecondSalePercentage!,
                isMaster: true,
                tokenUri: nil, 
                leverMinValues: nil,
                leverMaxValues: nil,
                leverStartValues: nil, 
                numAllowedUpdates: nil,
                uniqueTokenCreators: nil
            )

            // establish basic metadata for control tokens
            var layerIndex = masterTokenId + 1
            while layerIndex <= masterTokenId + layerCount {
                AsyncArtwork.metadata[layerIndex] = NFTMetadata(
                    id: layerIndex,
                    platformFirstSalePercentage: platformFirstSalePercentage == nil ? AsyncArtwork.defaultPlatformFirstSalePercentage : platformFirstSalePercentage!,
                    platformSecondSalePercentage: platformSecondSalePercentage == nil ? AsyncArtwork.defaultPlatformSecondSalePercentage : platformSecondSalePercentage!,
                    isMaster: false,
                    tokenUri: nil, 
                    leverMinValues: nil,
                    leverMaxValues: nil,
                    leverStartValues: nil, 
                    numAllowedUpdates: nil,
                    uniqueTokenCreators: nil
                )

                layerIndex = layerIndex + 1
            }

            AsyncArtwork.expectedTokenSupply = AsyncArtwork.expectedTokenSupply + layerCount + 1

            emit CreatorWhitelisted(
                tokenId: masterTokenId,
                layerCount: layerCount,
                creator: creatorAddress
            )
        }
    }

    // used to return data to the public, hiding the update functions
    pub struct interface NFTMetadataPublic {
        pub let id: UInt64
        pub let isMaster: Bool
        pub var uri: String?
        pub var isUriLocked: Bool
        pub var platformFirstSalePercentage: UFix64
        pub var platformSecondSalePercentage: UFix64
        pub var tokenSoldOnce: Bool
        pub var numControlLevers: Int?
        pub var numRemainingUpdates: Int64?
        pub fun getLeverValue(id: UInt64): Int64
        pub fun getLevers(): {UInt64: ControlLever}
        pub fun getUniqueTokenCreators(): [Address]
    }

    pub struct NFTMetadata: NFTMetadataPublic {
        pub let id: UInt64

        // whether or not this NFT represents a master token or a control token
        pub let isMaster: Bool

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

        // The number of control levers that this control token has
        pub var numControlLevers: Int?
        
        // The number of allowed updates that users can enact on the control levers
        pub var numRemainingUpdates: Int64?

        pub var owner: Address?

        // Control levers that can be used to tweak NFT metadata
        // needs to be private so that people can't change the metadata in the ControlTokens by calling updateValue
        access(self) let levers: {UInt64: ControlLever}

        // An array of addresses who receive a cut of the profits when this NFT is sold
        access(self) var uniqueTokenCreators: [Address]?

        pub fun getUniqueTokenCreators(): [Address] {
            if (self.uniqueTokenCreators != nil) {
                return self.uniqueTokenCreators!
            } else {
                return []
            }
        }

        pub fun getLeverValue(id: UInt64): Int64 {
            pre {
                self.levers[id] != nil : "Lever with id does not exist"
            }
            return self.levers[id]!.currentValue
        }

        pub fun updatePlatformSalesPercentages(_ platformFirstSalePercentage: UFix64,_ platformSecondSalePercentage: UFix64) {
            self.platformFirstSalePercentage = platformFirstSalePercentage
            self.platformSecondSalePercentage = platformSecondSalePercentage

            emit PlatformSalePercentageUpdated(
                tokenId: self.id,
                platformFirstPercentage: platformFirstSalePercentage,
                platformSecondPercentage: platformSecondSalePercentage
            )
        }

        pub fun setTokenSoldOnce() {
            pre {
                self.tokenSoldOnce == false : "tokenSoldOnce is already true"
            }
            self.tokenSoldOnce = true
            emit TokenSoldOnce(tokenId: self.id)
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

        pub fun updateOwner(_ owner: Address) {
            self.owner =  owner
        }

        pub fun initializeControlToken(
            uri: String,
            leverMinValues: [Int64],
            leverMaxValues: [Int64],
            leverStartValues: [Int64],
            numAllowedUpdates: Int64,
            uniqueTokenCreators: [Address],
            owner: Address
        ) {
            pre {
                !self.isMaster : "Unexpectedly tried to initialize master token as control token"
                self.uri == nil : "Token uri non-nil on unitialized control token"
                self.levers.length == 0 : "Levers are non-empty on unitialized control token"
                self.numRemainingUpdates == nil : "Num remaining updates non-nil on unitialized control token"
                self.uniqueTokenCreators == nil : "Unqiue token creators non-nill on unitialized control token"
                self.owner == nil : "Owner is initialized on non-initialized master token"
            }
            self.uri = uri
            self.uniqueTokenCreators = uniqueTokenCreators
            self.owner = owner
            self.numRemainingUpdates = numAllowedUpdates

            var i: UInt64 = 0
            while i < UInt64(leverStartValues.length) {
                self.levers[i] = ControlLever(minValue: leverMinValues[i], maxValue: leverMaxValues[i], startValue: leverStartValues[i])
                i = i + 1
            }
        }

        pub fun initializeMasterToken(uri: String, uniqueTokenCreators: [Address], owner: Address) {
            pre {
                self.isMaster : "Tried to intialize control token as master token"
                self.uri == nil : "Token uri is initialized on non-initialized master token"
                self.uniqueTokenCreators == nil : "uniqueTokenCreators initialized on non-intialized master token"
                self.owner == nil : "Owner is initialized on non-initialized master token"
            }
            self.uri = uri
            self.uniqueTokenCreators = uniqueTokenCreators
            self.owner = owner
        }

        pub fun updateControlTokenLevers(leverIds: [UInt64], newLeverValues: [Int64]): [Int64] {
            pre {
                !self.isMaster : "Cannot update levers on a master token"
                self.numRemainingUpdates != nil && self.numRemainingUpdates! > 0 : "No remaining updates for NFT"
            }

            let newValues: [Int64] = []
            var i: UInt64 = 0
            while i < UInt64(leverIds.length) {
                if self.levers[leverIds[i]] == nil {
                    panic("Attempted to update invalid lever id")
                } else {
                    self.levers[leverIds[i]]!.updateValue(newLeverValues[i])
                    newValues.append(self.levers[leverIds[i]]!.currentValue)
                }
                i = i + 1
            }

            self.numRemainingUpdates = self.numRemainingUpdates! - 1

            return newValues
        }

        pub fun getLevers(): {UInt64: ControlLever} {
            return self.levers
        }

        init (
            id: UInt64,
            platformFirstSalePercentage: UFix64,
            platformSecondSalePercentage: UFix64,
            isMaster: Bool,
            tokenUri: String?, 
            leverMinValues: [Int64]?,
            leverMaxValues: [Int64]?,
            leverStartValues: [Int64]?, 
            numAllowedUpdates: Int64?,
            uniqueTokenCreators: [Address]?
        ) {
            self.id = id
            self.platformFirstSalePercentage = platformFirstSalePercentage
            self.platformSecondSalePercentage = platformSecondSalePercentage
            self.isMaster = isMaster
            self.uri = tokenUri
            self.isUriLocked = false
            self.numControlLevers = leverStartValues == nil ? (nil as Int?) : leverStartValues!.length
            self.numRemainingUpdates = numAllowedUpdates
            self.tokenSoldOnce = false
            self.uniqueTokenCreators = uniqueTokenCreators
            self.levers = {}
            self.owner = nil
            if leverMinValues != nil && leverMaxValues != nil && leverStartValues != nil {
                var i: UInt64 = 0
                while i < UInt64(leverStartValues!.length) {
                    self.levers[i] = ControlLever(minValue: leverMinValues![i], maxValue: leverMaxValues![i], startValue: leverStartValues![i])
                    i = i + 1
                }
            }
        }
    }

    // The resource which manages all business logic related to AsyncArtwork
    // Consider giving marketplace contract a capability to this admin
    pub resource Admin  {
        // Admin can update the platform sales percentages for a given token
        pub fun updatePlatformSalePercentageForToken(
            tokenId: UInt64,
            platformFirstSalePercentage: UFix64,
            platformSecondSalePercentage: UFix64
        ) {
            pre {
                AsyncArtwork.isSalesPercentageValid(platformFirstSalePercentage) : "Cannot update. Invalid platformFirstSalePercentage value"
                AsyncArtwork.isSalesPercentageValid(platformSecondSalePercentage) : "Cannot update. Invalid platformSecondSalePercentage value"
                AsyncArtwork.metadata.containsKey(tokenId) : "Metadata for token id doesn't exist"
            }

            AsyncArtwork.metadata[tokenId]!.updatePlatformSalesPercentages(platformFirstSalePercentage, platformSecondSalePercentage)
        }

        // Admin can set the "tokenSoldOnce" flag on a piece of metadata manually
        pub fun setTokenDidHaveFirstSaleForToken(tokenId: UInt64) {
            pre {
                AsyncArtwork.metadata[tokenId] != nil : "TokenId does not exist"
            }
            AsyncArtwork.metadata[tokenId]!.setTokenSoldOnce()
        }

        // Admin can update the expectedTokenSupply state variable
        // We may not need this if this is only used to increment the expected token supply for whitelistTokenForCreator
        // if there are other reasons why we would want this value to change (in a more custom way) then we can leave this
        pub fun setExpectedTokenSupply (newExpectedTokenSupply: UInt64) {
            pre {
                newExpectedTokenSupply > AsyncArtwork.expectedTokenSupply : "Cannot move the expectedTokenSupply backwards. Would mint NFTs with duplicate ids."
            }
            AsyncArtwork.expectedTokenSupply = newExpectedTokenSupply
        }

        // Admin can update the default sales percentages attached to new tokens
        pub fun updateDefaultPlatformSalesPercentage (
            platformFirstSalePercentage: UFix64,
            platformSecondSalePercentage: UFix64
        ) {
            pre {
                AsyncArtwork.isSalesPercentageValid(platformFirstSalePercentage) : "Invalid new default platformFirstSalePercentage"
                AsyncArtwork.isSalesPercentageValid(platformSecondSalePercentage) : "Invalid new default platformSecondSalePercentage"
            }
            AsyncArtwork.defaultPlatformFirstSalePercentage = platformFirstSalePercentage
            AsyncArtwork.defaultPlatformSecondSalePercentage = platformSecondSalePercentage

            emit DefaultPlatformSalePercentageUpdated(
                defaultPlatformFirstSalePercentage: platformFirstSalePercentage,
                defaultPlatformSecondSalePercentage: platformSecondSalePercentage
            )
        }

        // Admin can update the artist second sale percentage
        pub fun updateArtistSecondSalePercentage(
            artistSecondSalePercentage: UFix64
        ) {
            pre {
                AsyncArtwork.isSalesPercentageValid(artistSecondSalePercentage) : "Invalid new artistSecondSalePercentage"
            }

            AsyncArtwork.artistSecondSalePercentage = artistSecondSalePercentage

            emit ArtistSecondSalePercentUpdated(artistSecondPercentage: artistSecondSalePercentage)
        }

        // Admin can update the URI associated with a specific token
        pub fun updateTokenURI(
            tokenId: UInt64,
            uri: String
        ) {
            pre {
                AsyncArtwork.metadata.containsKey(tokenId) : "Token with tokenId does not exist in metadata mapping"
            }
            AsyncArtwork.metadata[tokenId]!.updateUri(uri)
        }

        // Admin can lock the token uri
        pub fun lockTokenURI(
            tokenId: UInt64
        ) {
            pre {
                AsyncArtwork.metadata.containsKey(tokenId): "Token with tokenId does not exist in metadata mapping"
            }
            AsyncArtwork.metadata[tokenId]!.lockUri()
        }

        pub fun withdrawTips(): @FungibleToken.Vault {
            return <- AsyncArtwork.tipVault.withdraw(amount: AsyncArtwork.tipVault.balance)
        }
    }

    // Public getter for the metadata of any token
    pub fun getNFTMetadata(tokenId: UInt64): NFTMetadata{NFTMetadataPublic} {
        pre {
            self.metadata.containsKey(tokenId) : "token id does not exist in metadata mapping"
        }
        let publicMetadata: NFTMetadata{NFTMetadataPublic} = self.metadata[tokenId]!
        return publicMetadata
    }

    // get tip balance
    pub fun getTipBalance(): UFix64 {
        return self.tipVault.balance
    }

	init() {
        self.collectionStoragePath = /storage/AsyncArtworkCollection
        self.collectionPrivatePath = /private/AsyncArtworkCollection
        self.collectionPublicPath = /public/AsyncArtworkCollection
        self.adminStoragePath = /storage/AsyncArtworkAdmin
        self.adminPrivatePath = /private/AsyncArtworkAdmin
        self.minterStoragePath = /storage/AsyncArtworkMinter
        self.minterPrivatePath = /private/AsyncArtworkMinter

        self.totalSupply = 0
        self.expectedTokenSupply = 0
        self.metadata = {}
        self.defaultPlatformFirstSalePercentage = 10.0
        self.defaultPlatformSecondSalePercentage = 5.0
        self.artistSecondSalePercentage = 10.0

        self.tipVault <- FlowToken.createEmptyVault()

        // Collection
        let collection <- self.createEmptyCollection()
        self.account.save(<-collection, to: self.collectionStoragePath)

        self.account.link<&{NonFungibleToken.Provider, AsyncCollectionPrivate}>(
            self.collectionPrivatePath,
            target: self.collectionStoragePath
        )

        self.account.link<&{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, AsyncCollectionPublic}>(
            self.collectionPublicPath,
            target: self.collectionStoragePath
        )

        // Admin
        let admin <- create Admin()
        self.account.save(<-admin, to: self.adminStoragePath)

        self.account.link<&Admin>(
            self.adminPrivatePath,
            target: self.adminStoragePath
        )

        // Minter
        let minter <- create Minter()
        self.account.save(<-minter, to: self.minterStoragePath)

        self.account.link<&Minter>(
            self.minterPrivatePath,
            target: self.minterStoragePath
        )

        emit ContractInitialized()
	}
}