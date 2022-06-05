import NonFungibleToken from "./NonFungibleToken.cdc"
import FungibleToken from "./FungibleToken.cdc"
import FlowToken from "./FlowToken.cdc"
import FUSD from "./FUSD.cdc"
import MetadataViews from "./MetadataViews.cdc"

// Authors: Ishan Ghimire, Sam Orend
// This contract manages AsyncArtwork NFTs. For more details see: https://github.com/asyncart/async-flow/tree/main/cadence/contracts and https://github.com/asyncart/async-contracts/blob/master/contracts/AsyncArtwork_v2.sol
pub contract AsyncArtwork: NonFungibleToken {

    // The paths at which resources will be stored, and capabilities linked
    pub let collectionStoragePath: StoragePath 
    pub let collectionPrivatePath: PrivatePath
    pub let collectionPublicPath: PublicPath
    pub let collectionMetadataViewResolverPublicPath: PublicPath
    pub let adminStoragePath: StoragePath
    pub let adminPrivatePath: PrivatePath
    pub let minterStoragePath: StoragePath
    pub let minterPrivatePath: PrivatePath
    
    // The number of NFTs minted
    pub var totalSupply: UInt64

    // The number of tokens which have been allocated an id for minting
    pub var expectedTokenSupply: UInt64

    // a default value for the second sales percentage assigned to an NFT when whitelisted
    // i.e. set to 0.05 to represent a 5% cut
    pub var defaultPlatformSecondSalePercentage: UFix64

    // Second sale percentage for artists platform wide
    // i.e. set to 0.05 to represent a 5% cut
    // @notice this percentage is shared between all artists
    pub var artistSecondSalePercentage: UFix64

    // Recipient of platform royalties on AsyncArtwork sales
    pub var asyncSaleFeesRecipient: Address

    // A mapping of ids (from minted NFTs) to the metadata associated with them
    access(self) let metadata: {UInt64 : NFTMetadata}

    access(self) let tipVault: @FungibleToken.Vault

    // A mapping of currency type identifiers to expected paths
    access(self) let currencyPaths: {String: Paths}

    // A mapping of currency type identifiers to intermediary claims vaults
    access(self) let claimsVaults: @{String: FungibleToken.Vault}

    // A mapping of currency type identifiers to {User Addresses -> Amounts of currency they are owed}
    access(self) let payoutClaims: {String: {Address: UFix64}}

    // Emitted when contract is deployed
    pub event ContractInitialized()

    // Emitted when an NFT is withdrawn from a Collection
    pub event Withdraw(id: UInt64, from: Address?)

    // Emitted when an NFT is deposited to a Collection
    pub event Deposit(id: UInt64, to: Address?)
    
    // Emitted when a new the permissions of a user with respect to a control token are changed by the token owner
    pub event PermissionUpdated(
        tokenId: UInt64,
        tokenOwner: Address,
        permissioned: Address,
        granted: Bool
    )

    // Emitted when the 'Minter' allocates tokenId for minting by a specific creator
    pub event CreatorWhitelisted(
        tokenId: UInt64,
        layerCount: UInt64,
        creator: Address
    )

    // Emitted when the platform's fee percentage for a specific token is changed
    pub event PlatformSalePercentageUpdated(
        tokenId: UInt64,
        platformSecondPercentage: UFix64
    )

    // Emitted when the default platform sale percentage changes
    pub event DefaultPlatformSalePercentageUpdated(
        defaultPlatformSecondSalePercentage: UFix64
    )

    // Emitted when the uniform artist's second sale percentage is updated
    pub event ArtistSecondSalePercentUpdated(artistSecondPercentage: UFix64)

    // Emitted when a permissioned user updates the values of the levers of a control token
    pub event ControlLeverUpdated(
        tokenId: UInt64,
        priorityTip: UFix64,
        numRemainingUpdates: Int64,
        leverIds: [UInt64],
        previousValues: [Int64],
        updatedValues: [Int64]
    )

    // Emitted when the Admin whitelists a currency for use with AsyncArtwork royalties
    pub event CurrencyWhitelisted(currency: String)

    // Emitted when the Admin unwhitelists a currency for use with AsyncArtwork royalties
    pub event CurrencyUnwhitelisted(currency: String)

    // A structure used to encompass the expected paths for a consistent entity / resource
    pub struct Paths {
        pub var public: PublicPath
        pub var private: PrivatePath
        pub var storage: StoragePath

        init(_ _public: PublicPath, _ _private: PrivatePath, _ _storage: StoragePath) {
            self.public = _public 
            self.private = _private 
            self.storage = _storage 
        }
    }

    // Gets the expected paths of the supported currencies
    pub fun getCurrencyPaths(): {String: Paths} {
        return self.currencyPaths
    }

    // Check if a specific currency is supported for AsyncArtwork royalties
    pub fun isCurrencySupported(currency: String): Bool {
        return self.currencyPaths.containsKey(currency) &&
               self.claimsVaults.containsKey(currency) &&
               self.payoutClaims.containsKey(currency)
    }

    // A structure managing a value of an attribute of a control token. 
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

    // The literal NFT that signifies ownership of an AsyncArt NFT
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {

        // The id in the NFT is a pointer to its metadata stored on contract
        pub let id: UInt64

        // Metadata standard implementation
        pub fun getViews() : [Type] {
            return [
                Type<String>(),
                Type<{UInt64: ControlLever}>(),
                Type<[Address]>(),
                Type<MetadataViews.Royalties>()
            ]
        }

        // Returns the expected data for each type, metadata standard implementation in conjunction with getViews
        pub fun resolveView(_ type: Type): AnyStruct {
            let metadata = AsyncArtwork.getNFTMetadata(tokenId: self.id)

            if type == Type<String>() {
                return metadata.uri
            } else if type == Type<{UInt64: ControlLever}>() {
                return metadata.getLevers()
            } else if type == Type<[Address]>() {
                return metadata.getUniqueTokenCreators()
            } else if type == Type<MetadataViews.Royalties>() {
                let artistsPercentage: UFix64 = AsyncArtwork.artistSecondSalePercentage
                let platformPercentage: UFix64 = metadata.platformSecondSalePercentage
                
                let recipients: [Address] = metadata.getUniqueTokenCreators()
                recipients.append(AsyncArtwork.asyncSaleFeesRecipient)

                let royalties: [MetadataViews.Royalty] = []

                var i: UInt64 = 0
                while i < UInt64(recipients.length) {
                    let recipientAcct = getAccount(recipients[i])
                    var FTReceiverCapability = recipientAcct.getCapability<&{FungibleToken.Receiver}>(MetadataViews.getRoyaltyReceiverPublicPath())
                    if FTReceiverCapability == nil || !FTReceiverCapability.check() {
                        log("AsyncArtwork: Could not retrieve recipient Generic FT receiver")

                        // if this fails, try to add their expected flowTokenVault's receiver. 
                        // even if payment isn't in flowtoken, marketplace may grab the address from the receiver and send to correct receiver
                        // @notice if this capability is invalid, the requester may still be able to find a valid receiverusing its associated address
                        // but this contract will not further search for a valid capability for the recipient
                        FTReceiverCapability = recipientAcct.getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                    }
                    var cut: UFix64 = recipients.length > 0 ? artistsPercentage / UFix64(recipients.length - 1) : 0.0
                    var description: String = "Unique token creator cut"

                    if i == UInt64(recipients.length) - 1 {
                        // is platform
                        cut = platformPercentage
                        description = "Platform (asyncSaleFeesRecipient) cut"
                    }

                    royalties.append(MetadataViews.Royalty(FTReceiverCapability, cut, description))
                    
                    i = i + 1
                }

                return MetadataViews.Royalties(royalties)
            } else {
                return nil
            }
        }

        init (id: UInt64) {
            self.id = id
        }
    }

    // Auth is a special resource that can only be instantiated by this contract. It enables this contract to authenticate its calls to public functions that live in User's AsyncCollections.
    pub resource Auth {}

    // Private interface to a user's AsyncCollection
    pub resource interface AsyncCollectionPrivate {

        // Mint a "Master Token" NFT that the Minter has allocated to this creator
        pub fun mintMasterToken(
            id: UInt64, 
            artworkUri: String, 
            controlTokenArtists: [Address], 
            uniqueArtists: [Address]
        ) 

        // Mint a "Control Token" NFT which controls certain parameters of a Master Token NFT.
        // User must have been permissioned to mint control token by Master Token creator.
        pub fun mintControlToken(
            id: UInt64,
            tokenUri: String, 
            leverMinValues: [Int64], 
            leverMaxValues: [Int64], 
            leverStartValues: [Int64],
            numAllowedUpdates: Int64,
            additionalCollaborators: [Address]
        )

        // Update the value of the control token levers on a permissioned token
        pub fun useControlToken(
            id: UInt64, 
            leverIds: [UInt64], 
            newLeverValues: [Int64], 
            renderingTip: @FungibleToken.Vault?
        )

        // Change the permissions of another user with respect to a given control token
        pub fun grantControlPermission(id: UInt64, permissionedUser: Address, grant: Bool)

        // If a user's "owner" field on its metadata goes out of whack. They can manually assert that this address owns all NFTs in its mapppings.
        pub fun updateOwnerForOwnedNFTs()

        // Claim owed royalty payments in a specifc currency
        pub fun claimPayout(currency: String): @FungibleToken.Vault
    }

    // Public interface to a user's AsyncCollection
    pub resource interface AsyncCollectionPublic {

        // The method this contract uses to add a "master token id" that was allocated for this user to mint to its mappings
        pub fun reserveMasterMint(id: UInt64, layerCount: UInt64, auth: @AsyncArtwork.Auth)

        // The method this contract uses to add a "control token id" that was allocated for this user to mint to its mappings
        pub fun reserveControlMint(id: UInt64, auth: @AsyncArtwork.Auth)

        // The method this contract uses to change the permissions for the owner of this collection for a specific control token
        pub fun updateControlPermission(id: UInt64, grant: Bool, auth: @AsyncArtwork.Auth)

        // Return the master token ids that this creator has yet to mint
        pub fun getMasterMintReservation(): {UInt64: UInt64}

        // Return the control token ids that this creator has yet to mint
        pub fun getControlMintReservation(): {UInt64: UInt64}
        
        // Return the control token ids that this user has permission for
        pub fun getControlUpdate(): {UInt64: UInt64}
    }

    // The async colleciton resource that every user who interacts with AsyncArt NFTs must have
    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, AsyncCollectionPublic, AsyncCollectionPrivate, MetadataViews.ResolverCollection {
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

        // Mints a master token. Minter has to be whitelisted to mint the token along with the correct number of control tokens. 
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
                uniqueArtists.length <= 500 : "Unique artists length too long, over 500"
            }

            post {
                !self.masterMintReservation.containsKey(id) : "Reservation not removed after mint"
                (self.ownedNFTs.containsKey(id) && self.borrowNFT(id: id).id == id) : "Did not receive minted token"
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

        // Mints a control token. Minter must have been granted ability by master token minter 
        // (of the master token corresponding to the control token being minted).
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
                (self.ownedNFTs.containsKey(id) && self.borrowNFT(id: id).id == id) : "Did not receive minted token"
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

        // Modifies the value(s) of a control token. Modifier must have been granted control permission.
        pub fun useControlToken(
            id: UInt64, 
            leverIds: [UInt64], 
            newLeverValues: [Int64], 
            renderingTip: @FungibleToken.Vault?
        ) {
            pre {
                (self.ownedNFTs.containsKey(id) && self.borrowNFT(id: id).id == id) || self.controlUpdate.containsKey(id) : "Not authorized to use control token"
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

        // Grants an account the ability to modify control token values.
        pub fun grantControlPermission(id: UInt64, permissionedUser: Address, grant: Bool) {
            pre {
                (self.ownedNFTs.containsKey(id) && self.borrowNFT(id: id).id == id) : "Not authorized to grant permissions for this token"
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

        // Updates the central record of NFT ownership, which is required due to FLOW's model. 
        pub fun updateOwnerForOwnedNFTs() {
            pre {
                self.owner != nil : "Collection doesn't have owner"
            }

            for id in self.ownedNFTs.keys {
                let NFT = self.borrowNFT(id: id)
                let tokenId = NFT.id

                if tokenId != id {
                    panic("NFT id does not match key id in ownedNFTs")
                }

                let metadata = AsyncArtwork.metadata[tokenId]
                if metadata != nil && (metadata!.owner == nil || metadata!.owner != self.owner!.address) {
                    AsyncArtwork.metadata[tokenId]!.updateOwner(self.owner!.address)
                }
            }
        }

        // Lets users who didn't have public capabilities configured at a time of a token purchase, to claim the money they are owed.
        pub fun claimPayout(currency: String): @FungibleToken.Vault {
            pre {
                self.owner != nil : "Cannot perform operation while client in transit"
                AsyncArtwork.payoutClaims[currency] != nil : "Currency type is not supported"
                AsyncArtwork.payoutClaims[currency]![self.owner!.address] != nil : "Sender does not have any payouts to claim for this currency"
            }

            let withdrawAmount: UFix64 = AsyncArtwork.payoutClaims[currency]![self.owner!.address]!
            let claimsVault <- AsyncArtwork.claimsVaults.remove(key: currency)!
            let payout: @FungibleToken.Vault <- claimsVault.withdraw(amount: withdrawAmount)

            destroy <- AsyncArtwork.claimsVaults.insert(key: currency, <- claimsVault)

            return <- payout
        }

        // =============================
        // AsyncCollectionPublic interface
        // =============================

        // Updates who can modify control token values.
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

        // Lets the smart contract grant resources held on user accounts, the ability to mint a master token.
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

        // Lets the smart contract grant resources held on user accounts, the ability to mint a control token.
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
        // MetadataViews.ResolverCollection interface
        // =============================        

        pub fun borrowViewResolver(id: UInt64): &{MetadataViews.Resolver} {
            let nft = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT?
            if nft == nil {
                panic("NFT for id not found")
            }
            if nft!.id != id {
                panic("NFT id does not match requested id")
            }
            let asyncArtworkNFT = nft! as! &AsyncArtwork.NFT 
            return asyncArtworkNFT as &{MetadataViews.Resolver}
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
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    // public function that anyone can call to create a new empty collection
    // @notice every user must have this collection to interact with AsyncArtwork NFTs
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    // returns whether or not a given sales percentage is a legal value
    access(self) fun isSalesPercentageValid(_ percentage: UFix64): Bool {
        return percentage < 1.0 && percentage >= 0.0
    }

    // Checks if string input is of a valid Flow currency format (implementing FungibleToken)
    access(self) fun isValidCurrencyFormat(_currency: String): Bool {
        // valid hex address, will abort otherwise
        _currency.slice(from: 2, upTo: 18).decodeHex()

        let periodUtf8: UInt8 = 46

        if _currency.slice(from: 0, upTo: 2) != "A." {
            // does not start with A. 
            return false 
        } else if _currency[18] != "." {
            // 16 chars not in address
            return false
        } else if !_currency.slice(from: 19, upTo: _currency.length).utf8.contains(periodUtf8) {
            // third dot is not present
            return false 
        } 

        // check if substring after last dot is "Vault"
        let contractSpecifier: String = _currency.slice(from: 19, upTo: _currency.length)
        var typeFirstIndex: Int = 0

        var i: Int = 0
        while i < contractSpecifier.length {
            if contractSpecifier[i] == "." {
                typeFirstIndex = i + 1
                break
            }
            i = i + 1
        }
        if contractSpecifier.slice(from: typeFirstIndex, upTo: contractSpecifier.length) != "Vault" {
            return false
        }
        
        return true 
    }

    // generalized payout of an amount of currency, to a recipient
    access(self) fun payout(
        recipient: Address,
        amount: @FungibleToken.Vault,
        currency: String
    ) {
        let receiverPath = self.currencyPaths[currency]!.public
        let vaultReceiver = getAccount(recipient).getCapability<&{FungibleToken.Receiver}>(receiverPath).borrow()

        if vaultReceiver != nil {
            vaultReceiver!.deposit(from: <- amount)
        } else {
            self.payClaims(recipient: recipient, amount: <- amount, currency: currency)
        }
    }

    // on payment failures, store payments to be claimed later
    access(self) fun payClaims(
        recipient: Address, 
        amount: @FungibleToken.Vault,
        currency: String
    ) {
        var newClaim: UFix64 = 0.0
        if self.payoutClaims[currency]![recipient] == nil {
            newClaim = amount.balance
        } else {
            newClaim = self.payoutClaims[currency]![recipient]! + amount.balance
        }
        self.payoutClaims[currency]!.insert(key: recipient, newClaim)

        let claimsVault <- self.claimsVaults.remove(key: currency)!
        claimsVault.deposit(from: <- amount)

        // This should always destroy an empty resource
        destroy <- self.claimsVaults.insert(key: currency, <- claimsVault)
    }

    // An admin resource that whitelists specific creators to be able to mint "Master Token" NFTs. These creators can then allocate control token artists, as desired, and within the bounds set.
    pub resource Minter {

		// Whitelist a master token for minting by an individual creator along with a certain number of component layers
        pub fun whitelistTokenForCreator(
            creatorAddress: Address,
            masterTokenId: UInt64,
            layerCount: UInt64,
            platformSecondSalePercentage: UFix64?
        ) {
            pre {
                masterTokenId == AsyncArtwork.expectedTokenSupply + 1 : "Master token id must be the same as the expectedTokenSupply"
                AsyncArtwork.metadata[masterTokenId] == nil : "NFT Metadata already exists at supplied masterTokenId"
                platformSecondSalePercentage == nil || AsyncArtwork.isSalesPercentageValid(platformSecondSalePercentage!) : "Invalid platformSecondSalePercentage value"
            }

            let creatorPublicAccount = getAccount(creatorAddress)
            let creatorAsyncPublicCollection = creatorPublicAccount.getCapability<&Collection{AsyncCollectionPublic}>(AsyncArtwork.collectionPublicPath).borrow() ?? panic("Address specified does not have public capability to AsyncCollectionPublic")
            creatorAsyncPublicCollection.reserveMasterMint(id: masterTokenId, layerCount: layerCount, auth: <- create AsyncArtwork.Auth())

            // establish basic metadata for master token
            AsyncArtwork.metadata[masterTokenId] = NFTMetadata(
                id: masterTokenId,
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

    // The public NFT metadata interface, available for every minted NFT via getNFTMetadata
    pub struct interface NFTMetadataPublic {
        pub let id: UInt64
        pub let isMaster: Bool
        pub var uri: String?
        pub var isUriLocked: Bool
        pub var platformSecondSalePercentage: UFix64
        pub var numControlLevers: Int?
        pub var numRemainingUpdates: Int64?
        pub var owner: Address?
        pub fun getLeverValue(id: UInt64): Int64
        pub fun getLevers(): {UInt64: ControlLever}
        pub fun getUniqueTokenCreators(): [Address]
    }


    // NFTMetadata resource created for every NFT. The same metadata resource is used for both master and control tokens.
    pub struct NFTMetadata: NFTMetadataPublic {

        pub let id: UInt64

        // whether or not this NFT represents a master token or a control token
        pub let isMaster: Bool

        // Metadata URI
        pub var uri: String?

        // Whether or not the uri can still be updated
        pub var isUriLocked: Bool

        // The percentage of the sale value of the NFT that should be given to the AsyncArt platform when this NFT is sold subsequently to the first time
        pub var platformSecondSalePercentage: UFix64

        // The number of control levers that this control token has
        pub var numControlLevers: Int?
        
        // The number of allowed updates that users can enact on the control levers
        pub var numRemainingUpdates: Int64?

        // Address of the owner of the NFT
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

        pub fun updatePlatformSalesPercentage(_ platformSecondSalePercentage: UFix64) {
            self.platformSecondSalePercentage = platformSecondSalePercentage

            emit PlatformSalePercentageUpdated(
                tokenId: self.id,
                platformSecondPercentage: platformSecondSalePercentage
            )
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

        // Called when a control token is first minted to set some core properties
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

        // Called when a master token is first minted to set some core properties
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

        // Update a series of control token values, and return the new values
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
            self.platformSecondSalePercentage = platformSecondSalePercentage
            self.isMaster = isMaster
            self.uri = tokenUri
            self.isUriLocked = false
            self.numControlLevers = leverStartValues == nil ? (nil as Int?) : leverStartValues!.length
            self.numRemainingUpdates = numAllowedUpdates
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

    // An administrative resource that is only owned by the platform
    pub resource Admin  {

        // Admin can update the platform sales percentages for a given token
        pub fun updatePlatformSalePercentageForToken(
            tokenId: UInt64,
            platformSecondSalePercentage: UFix64
        ) {
            pre {
                AsyncArtwork.isSalesPercentageValid(platformSecondSalePercentage) : "Cannot update. Invalid platformSecondSalePercentage value"
                AsyncArtwork.metadata.containsKey(tokenId) : "Metadata for token id doesn't exist"
            }

            AsyncArtwork.metadata[tokenId]!.updatePlatformSalesPercentage(platformSecondSalePercentage)
        }

        // Admin can update the expectedTokenSupply state variable
        pub fun setExpectedTokenSupply (newExpectedTokenSupply: UInt64) {
            pre {
                newExpectedTokenSupply > AsyncArtwork.expectedTokenSupply : "Cannot move the expectedTokenSupply backwards. Would mint NFTs with duplicate ids."
            }
            AsyncArtwork.expectedTokenSupply = newExpectedTokenSupply
        }

        // Admin can update its default sales royalties
        pub fun updateDefaultPlatformSalesPercentage (
            platformSecondSalePercentage: UFix64
        ) {
            pre {
                AsyncArtwork.isSalesPercentageValid(platformSecondSalePercentage) : "Invalid new default platformSecondSalePercentage"
            }
            AsyncArtwork.defaultPlatformSecondSalePercentage = platformSecondSalePercentage

            emit DefaultPlatformSalePercentageUpdated(
                defaultPlatformSecondSalePercentage: platformSecondSalePercentage
            )
        }

        // Admin can update the artists second sale royalties
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

        // Admin can lock the token uri associated with a specific NFT
        pub fun lockTokenURI(
            tokenId: UInt64
        ) {
            pre {
                AsyncArtwork.metadata.containsKey(tokenId): "Token with tokenId does not exist in metadata mapping"
            }
            AsyncArtwork.metadata[tokenId]!.lockUri()
        }

        // Admin can withdraw its tips from users
        pub fun withdrawTips(): @FungibleToken.Vault {
            return <- AsyncArtwork.tipVault.withdraw(amount: AsyncArtwork.tipVault.balance)
        }

        // Admin can whitelist a new currency for use with royalties
        pub fun whitelistCurrency(
            currency: String,
            currencyPublicPath: PublicPath,
            currencyPrivatePath: PrivatePath,
            currencyStoragePath: StoragePath,
            vault: @FungibleToken.Vault
        ) {
            pre {
                AsyncArtwork.isValidCurrencyFormat(_currency: currency) : "Currency identifier is invalid"
                !AsyncArtwork.isCurrencySupported(currency: currency): "Currency is already whitelisted"
            }

            post {
                AsyncArtwork.isCurrencySupported(currency: currency): "Currency not whitelisted successfully"
            }

            AsyncArtwork.currencyPaths[currency] = Paths(
                currencyPublicPath,
                currencyPrivatePath,
                currencyStoragePath
            )
            AsyncArtwork.payoutClaims.insert(key: currency, {})
            destroy <- AsyncArtwork.claimsVaults.insert(key: currency, <- vault)

            emit CurrencyWhitelisted(currency: currency)
        }

        // Admin can unwhitelist a currency for use with royalties
        // @notice This is a safe removal (checks if claims vault being removed is empty)
        pub fun unwhitelistCurrencySafe(
            currency: String
        ) {
            pre {
                AsyncArtwork.isCurrencySupported(currency: currency): "Currency is not whitelisted"
            }

            post {
                !AsyncArtwork.isCurrencySupported(currency: currency): "Currency unwhitelist failed"
            }

            AsyncArtwork.currencyPaths.remove(key: currency)
            AsyncArtwork.payoutClaims.remove(key: currency)

            let vault <- AsyncArtwork.claimsVaults.remove(key: currency) ?? panic("Could not retrieve claims vault for currency")
            if vault.balance > 0.0 {
                panic("Claims vault is non-empty")
            }
            destroy vault

            emit CurrencyUnwhitelisted(currency: currency)
        }

        // Admin can unwhitelist a currency for use with royalties
        // unwhitelist currency unchecked (doesn't check if claims vault being removed is empty)
        pub fun unwhitelistCurrencyUnchecked(
            currency: String
        ) {
            pre {
                AsyncArtwork.isCurrencySupported(currency: currency): "Currency is not whitelisted"
            }

            post {
                !AsyncArtwork.isCurrencySupported(currency: currency): "Currency unwhitelist failed"
            }

            AsyncArtwork.currencyPaths.remove(key: currency)
            AsyncArtwork.payoutClaims.remove(key: currency)

            // @notice this might permanently remove funds from claims
            let vault <- AsyncArtwork.claimsVaults.remove(key: currency) ?? panic("Could not retrieve claims vault for currency")

            // if any remaining, pay out to asyncSaleFeesRecipient to potentially manually payout later
            AsyncArtwork.payout(recipient: AsyncArtwork.asyncSaleFeesRecipient, amount: <- vault, currency: currency)

            emit CurrencyUnwhitelisted(currency: currency)
        }

        // Admin can update address to receive platform royalties
        pub fun setAsyncSaleFeesRecipient(newRecipient: Address) {
            AsyncArtwork.asyncSaleFeesRecipient = newRecipient
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

    // Public getter for the metadata of any token
    pub fun getAllNFTs(): [NFTMetadata{NFTMetadataPublic}] {
        let ret: [NFTMetadata{NFTMetadataPublic}] = []
        for id in self.metadata.keys {
            ret.append(self.getNFTMetadata(tokenId: id))
        }
        return ret
    }

    // get tip balance
    pub fun getTipBalance(): UFix64 {
        return self.tipVault.balance
    }

	init(flowTokenCurrencyType: String, fusdCurrencyType: String) {
        self.collectionStoragePath = /storage/AsyncArtworkCollection
        self.collectionPrivatePath = /private/AsyncArtworkCollection
        self.collectionPublicPath = /public/AsyncArtworkCollection
        self.collectionMetadataViewResolverPublicPath = /public/AsyncArtworkMetadataViews
        self.adminStoragePath = /storage/AsyncArtworkAdmin
        self.adminPrivatePath = /private/AsyncArtworkAdmin
        self.minterStoragePath = /storage/AsyncArtworkMinter
        self.minterPrivatePath = /private/AsyncArtworkMinter

        self.totalSupply = 0
        self.expectedTokenSupply = 0
        self.metadata = {}
        self.defaultPlatformSecondSalePercentage = 0.05
        self.artistSecondSalePercentage = 0.1
        self.asyncSaleFeesRecipient = self.account.address

        self.tipVault <- FlowToken.createEmptyVault()

        // To start, royalty "claims" are supported in FlowToken and FUSD
        self.claimsVaults <- {
            flowTokenCurrencyType: <- FlowToken.createEmptyVault(),
            fusdCurrencyType: <- FUSD.createEmptyVault()
        }
        
        self.currencyPaths = {
            flowTokenCurrencyType: Paths(
                /public/flowTokenReceiver,
                /private/asyncArtworkFlowTokenVault, // technically unknown standard -> opt for custom path
                /storage/flowTokenVault
            ),
            fusdCurrencyType: Paths(
                /public/fusdReceiver,
                /private/asyncArtworkFusdVault, // technically unknown standard -> opt for custom path
                /storage/fusdVault
            )
        }
        self.payoutClaims = {
            flowTokenCurrencyType: {},
            fusdCurrencyType: {}
        }

        // Collection
        let collection <- create Collection()
        self.account.save(<-collection, to: self.collectionStoragePath)

        self.account.link<&{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, AsyncCollectionPublic}>(
            self.collectionPublicPath,
            target: self.collectionStoragePath
        )

        self.account.link<&{NonFungibleToken.Provider, AsyncCollectionPrivate}>(
            self.collectionPrivatePath,
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