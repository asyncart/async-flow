import NonFungibleToken from "./NonFungibleToken.cdc"
import FungibleToken from "./FungibleToken.cdc"
import FlowToken from "./FlowToken.cdc"
import FUSD from "./FUSD.cdc"
import MetadataViews from "./MetadataViews.cdc"
import Royalties from "./Royalties.cdc"

pub contract Blueprints: NonFungibleToken {

    // The paths at which resources will be stored, and capabilities linked
    pub let collectionStoragePath: StoragePath
    pub let collectionPrivatePath: PrivatePath
    pub let collectionPublicPath: PublicPath
    pub let collectionMetadataViewResolverPublicPath: PublicPath
    pub let minterStoragePath: StoragePath
    pub let platformStoragePath: StoragePath
    pub let blueprintsClientStoragePath: StoragePath

    // The total number of Blueprint NFTs minted
    pub var totalSupply: UInt64

    // The default fee that the platform receives on primary NFT sales
    pub var defaultPlatformPrimaryFeePercentage: UFix64

    // The default fee that the platform receives on secondary NFT sales
    pub var defaultPlatformSecondarySalePercentage: UFix64

    // The default secondary sale royalty percentage for Blueprint artists
    pub var defaultBlueprintSecondarySalePercentage: UFix64

    // An index the manages an upper-bound on the number of possible NFTs
    pub var latestNftIndex: UInt64

    // An index of the number of Blueprints that have been prepared by the minter. (Note the key here is that each Blueprint is associated with a maximum number of NFTs)
    pub var blueprintIndex: UInt64

    // The address to pay platform fees to
    pub var asyncSaleFeesRecipient: Address

    // The address that controls the preparation of new blueprints
    access(self) var minterAddress: Address

    // NFT IDs -> Blueprint IDs
    access(self) let tokenToBlueprintID: {UInt64: UInt64}

    // Blueprint IDs -> Blueprint Metadata
    access(self) let blueprints: {UInt64: Blueprint}

    // A mapping of currency type identifiers to expected paths
    access(self) let currencyPaths: {String: Paths}

    // A mapping of currency type identifiers to intermediary claims vaults
    access(self) let claimsVaults: @{String: FungibleToken.Vault}

    // A mapping of currency type identifiers to {User Addresses -> Amounts of currency they are owed}
    access(self) let payoutClaims: {String: {Address: UFix64}}

    pub event ContractInitialized()

    // Emitted when a Blueprint NFT is withdrawn from its collection
    pub event Withdraw(id: UInt64, from: Address?)

    // Emitted when a Blueprint NFT is deposited to a new collection
    pub event Deposit(id: UInt64, to: Address?)

    // Emitted when a certain amount of Blueprint NFTs are minted
    // @param newCapacity is the number of Blueprint NFTs that can still be minted for this Blueprint ID
    pub event BlueprintMinted(
        blueprintID: UInt64,
        artist: Address,
        purchaser: Address,
        tokenId: UInt64,
        newCapacity: UInt64,
        seedPrefix: [UInt8]
    )

    // Emitted when the minter first prepares a Blueprint for an artist
    pub event BlueprintPrepared(
        blueprintID: UInt64,
        artist: Address,
        capacity: UInt64,
        blueprintMetadata: String,
        baseTokenUri: String
    )

    // Emitted when the settings for a specific Blueprint are updated
    pub event BlueprintSettingsUpdated(
        blueprintID: UInt64,
        price: UFix64,
        newMintAmountArtist: UInt64,
        newMintAmountPlatform: UInt64,
        newSaleState: UInt8,
        newMaxPurchaseAmount: UInt64 
    )
    
    // Emitted when the addresses of whitelisted buyers change (whitelisted buyers can purchase blueprints before the sale officially starts)
    pub event BlueprintWhitelistUpdated(
        blueprintID: UInt64,
        oldWhitelist: {Address: Bool},
        newWhitelist: {Address: Bool}
    )

    // Emitted when a Blueprint sale officialy starts
    pub event SaleStarted(blueprintID: UInt64)

    // Emitted whena Blueprint sale is paused
    pub event SalePaused(blueprintID: UInt64)

    // Emitted when a Blueprint sale is unpaused
    pub event SaleUnpaused(blueprintID: UInt64)

    // Emitted when a Blueprint Token URI is updated
    pub event BlueprintTokenUriUpdated(
        blueprintID: UInt64,
        newBaseTokenUri: String
    )

    // An event that reveals the seed associated with a Blueprint
    pub event BlueprintSeed(
        blueprintID: UInt64,
        randomSeed: String
    )

    // Emitted when a new currency is a whitelisted to work with royalties
    pub event CurrencyWhitelisted(currency: String)

    // Emitted when a new currency is unwhitelisted for royalties
    pub event CurrencyUnwhitelisted(currency: String)

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

    pub fun getCurrencyPaths(): {String: Paths} {
        return self.currencyPaths
    }

    pub fun isCurrencySupported(currency: String): Bool {
        return self.currencyPaths.containsKey(currency) &&
               self.claimsVaults.containsKey(currency) &&
               self.payoutClaims.containsKey(currency)
    }

    // A pre-royalty standard implementation of Royalties for Blueprint NFTs
    pub struct Royalty : Royalties.Royalty {

        // Recipients of royalty
        access(self) var recipients: [Address]

        // Percentages that each recipient will receive as royalty payment. This is a percentage of the total purchase price.
        access(self) var percentages: [UFix64]

        // The total percentage of purchase price that will be taken to payout the royalty described by this struct.
        access(self) var totalCut: UFix64
        
        init(_ recipients: [Address], _ percentages: [UFix64]) {
            post {
                self.totalCut <= 1.0 : "Royalty percentages cannot exceed 100%"
            }
            self.recipients = recipients
            self.percentages = percentages
            self.totalCut = 0.0

            for percentage in percentages {
                self.totalCut = self.totalCut + percentage
            }
        }

        // Calculate the number of tokens that would be taken for royalties given a purchase amount
        pub fun calculateRoyalty(type: Type, amount:UFix64) : UFix64? {
            if Blueprints.isCurrencySupported(currency: type.identifier) {
                return self.totalCut * amount
            } else {
                return nil
            }
        }
    
        // Distribute a lump sum royalty amount appropriately to all of the recipients
        pub fun distributeRoyalty(vault: @FungibleToken.Vault) {
            pre {
                Blueprints.isCurrencySupported(currency: vault.getType().identifier) : "Currency not supported"
            }

            let currency: String = vault.getType().identifier
            let totalPaymentAmount: UFix64 = vault.balance
            var i: Int = 0
            while i < self.recipients.length {
                let amount: @FungibleToken.Vault <- vault.withdraw(amount: self.percentages[i] * (1.0/self.totalCut) * totalPaymentAmount)
                Blueprints.payout(recipient: self.recipients[i], amount: <- amount, currency: currency)

                i = i + 1
            }

            // There should be zero tokens left, but purely to avoid loss of resource pay out anything remaining to platform
            Blueprints.payout(recipient: self.recipients[self.recipients.length - 1], amount: <- vault, currency: currency)
        }

        // Visualize the royalty distribution (recipients and their percentage allocations)
        pub fun displayRoyalty() : String? {
            var text = ""
            var i: Int = 0
            while i < self.recipients.length {
                text = text.concat(self.recipients[i].toString()).concat(": ").concat((self.percentages[i]*100.0).toString()).concat("%,")
                i = i + 1
            }
            text = text.slice(from: 0, upTo: text.length-1)
            return text
        }
    }

    // An enum for the possible sale states for a Blueprint
    pub enum SaleState: UInt8 {
        pub case notStarted 
        pub case started 
        pub case paused
    }

    // Public Blueprint metadata
    pub struct interface BlueprintPublic {
        pub var tokenUriLocked: Bool
        pub var mintAmountArtist: UInt64 
        pub var mintAmountPlatform: UInt64 
        pub var capacity: UInt64 
        pub var nftIndex: UInt64 
        pub var maxPurchaseAmount: UInt64? 
        pub var price: UFix64
        pub var artist: Address
        pub var currency: String 
        pub var baseTokenUri: String 
        pub var saleState: SaleState

        pub fun getPrimaryFeeRecipients(): [Address]
        pub fun getPrimaryFeePercentages(): [UFix64]
        pub fun getSecondaryFeeRecipients(): [Address]
        pub fun getSecondaryFeePercentages(): [UFix64]
    }

    // A representation of a Blueprint
    pub struct Blueprint: BlueprintPublic {
        pub var tokenUriLocked: Bool
        pub var mintAmountArtist: UInt64 
        pub var mintAmountPlatform: UInt64 
        pub var capacity: UInt64 
        pub var nftIndex: UInt64 
        pub var maxPurchaseAmount: UInt64? 
        pub var price: UFix64
        pub var artist: Address
        pub var currency: String 
        pub var baseTokenUri: String 
        pub var saleState: SaleState

        access(self) var primaryFeePercentages: [UFix64]
        access(self) var secondaryFeePercentages: [UFix64]
        access(self) var primaryFeeRecipients: [Address]
        access(self) var secondaryFeeRecipients: [Address]

        // maps whitelisted addresses to if they've claimed
        access(contract) var whitelist: {Address: Bool}

        pub var blueprintMetadata: String

        pub fun updateSettings(
            _price: UFix64,
            _mintAmountArtist: UInt64,
            _mintAmountPlatform: UInt64,
            _newSaleState: SaleState,
            _newMaxPurchaseAmount: UInt64?
        ) {
            self.price = _price
            self.mintAmountArtist = _mintAmountArtist
            self.mintAmountPlatform = _mintAmountPlatform
            self.saleState = _newSaleState
            self.maxPurchaseAmount = _newMaxPurchaseAmount != nil ? _newMaxPurchaseAmount : self.maxPurchaseAmount
        }

        pub fun addToWhitelist(
            _whitelistAdditions: [Address]
        ) {
            pre {
                _whitelistAdditions.length <= 500 : "Whitelist additions too long, over 500 entries"
            }

            for newAddress in _whitelistAdditions {
                if !self.whitelist.containsKey(newAddress) {
                    self.whitelist.insert(key: newAddress, false)
                }
            }
        }

        pub fun removeFromWhitelist(
            _whitelistRemovals: [Address]
        ) {
            pre {
                _whitelistRemovals.length <= 500 : "Whitelist removals too long, over 500 entries"
            }

            // unbounded loop may be flagged by auditor
            for newAddress in _whitelistRemovals {
                if self.whitelist.containsKey(newAddress) {
                    self.whitelist.remove(key: newAddress)
                }
            }
        }

        pub fun overwriteWhitelist(
             _whitelistedAddresses: [Address]
        ) {
            self.whitelist = {}
            self.addToWhitelist(_whitelistAdditions: _whitelistedAddresses)
        }

        access(self) fun feesApplicable(_feeRecipients: [Address], _feePercentages: [UFix64]): Bool {
            if _feeRecipients.length > 500 {
                return false
            }

            if _feeRecipients.length == _feePercentages.length &&  _feeRecipients.length > 0 {

                var totalPercent: UFix64 = 0.0 
                for percentage in _feePercentages {
                    totalPercent = totalPercent + percentage 
                }
                if totalPercent > 1.0 {
                    return false 
                }

                return true
            } 

            return false
        }

        pub fun setFeeRecipients(
            _primaryFeeRecipients: [Address],
            _primaryFeePercentages: [UFix64],
            _secondaryFeeRecipients: [Address],
            _secondaryFeePercentages: [UFix64]
        ) {
            pre {
                self.feesApplicable(_feeRecipients: _primaryFeeRecipients, _feePercentages: _primaryFeePercentages) : "Primary fees invalid"
                self.feesApplicable(_feeRecipients: _secondaryFeeRecipients, _feePercentages: _secondaryFeePercentages) : "Secondary fees invalid"
            }

            self.primaryFeeRecipients = _primaryFeeRecipients
            self.primaryFeePercentages = _primaryFeePercentages
            self.secondaryFeeRecipients = _secondaryFeeRecipients
            self.secondaryFeePercentages = _secondaryFeePercentages
        }

        pub fun setSaleState(
            state: SaleState
        )  {
            self.saleState = state
        }

        pub fun claimWhitelistPiece(user: Address) {
            pre {
                // good for audit but error message should be cleaned up later
                self.whitelist.containsKey(user) : "User not in whitelist, code execution should have never reached here"
            }

            self.whitelist[user] = true
        }

        pub fun updateAfterMint(
            _nftIndex: UInt64,
            _capacity: UInt64 
        ) {
            self.nftIndex = _nftIndex 
            self.capacity = _capacity
        }

        pub fun decrementMintAmountValues(platformDecrement: UInt64, artistDecrement: UInt64) {
            self.mintAmountPlatform = self.mintAmountPlatform - platformDecrement 
            self.mintAmountArtist = self.mintAmountArtist - artistDecrement
        }

        pub fun updateBaseTokenUri(newBaseTokenUri: String) {
            self.baseTokenUri = newBaseTokenUri
        }

        pub fun lockTokenUri() {
            self.tokenUriLocked = true
        }

        pub fun isUserWhitelisted(user: Address): Bool {
            if !self.whitelist.containsKey(user) {
                return false
            } else {
                return !self.whitelist[user]! 
            }
        }

        pub fun getPrimaryFeeRecipients(): [Address] {
            if self.primaryFeeRecipients.length == 0 {
                return [Blueprints.asyncSaleFeesRecipient]
            } else {
                return self.primaryFeeRecipients
            }
        }

        pub fun getPrimaryFeePercentages(): [UFix64] {
            if self.primaryFeePercentages.length == 0 {
                return [Blueprints.defaultPlatformPrimaryFeePercentage]
            } else {
                return self.primaryFeePercentages
            }
        }

        pub fun getSecondaryFeeRecipients(): [Address] {
            if self.secondaryFeeRecipients.length == 0 {
                return [Blueprints.asyncSaleFeesRecipient, self.artist]
            } else {
                return self.secondaryFeeRecipients
            }
        }

        pub fun getSecondaryFeePercentages(): [UFix64] {
            if self.secondaryFeePercentages.length == 0 {
                return [Blueprints.defaultPlatformSecondarySalePercentage, Blueprints.defaultBlueprintSecondarySalePercentage]
            } else {
                return self.secondaryFeePercentages
            }
        }

        init(
            _artist: Address,
            _capacity: UInt64,
            _price: UFix64,
            _currency: String,
            _baseTokenUri: String,
            _initialWhitelist: [Address],
            _mintAmountArtist: UInt64,
            _mintAmountPlatform: UInt64,
            _blueprintMetadata: String,
            _maxPurchaseAmount: UInt64?
        ) {
            pre {
                // Should we instead be asserting that the currency is supported not just a valid format
                Blueprints.isValidCurrencyFormat(_currency: _currency) : "Currency type is invalid"
            }

            self.tokenUriLocked = false
            self.saleState = SaleState.notStarted
            self.nftIndex = Blueprints.latestNftIndex
            self.primaryFeePercentages = []
            self.secondaryFeePercentages = []
            self.primaryFeeRecipients = []
            self.secondaryFeeRecipients = []

            self.artist = _artist
            self.capacity = _capacity
            self.price = _price
            self.currency = _currency
            self.baseTokenUri = _baseTokenUri
            self.mintAmountArtist = _mintAmountArtist
            self.mintAmountPlatform = _mintAmountPlatform
            self.maxPurchaseAmount = _maxPurchaseAmount
            self.blueprintMetadata = _blueprintMetadata

            self.whitelist = {}
            self.addToWhitelist(_whitelistAdditions: _initialWhitelist)

            Blueprints.latestNftIndex = Blueprints.latestNftIndex + _capacity
        }
    }

    // Get the public metadata available for all Blueprints that have been prepared
    pub fun getBlueprints(): [Blueprint{BlueprintPublic}] {
        return self.blueprints.values
    }

    // Get the public metadata that is available for a specific Blueprint
    pub fun getBlueprint(blueprintID: UInt64): Blueprint{BlueprintPublic}? {
        if self.blueprints.containsKey(blueprintID) {
            return self.blueprints[blueprintID]!
        } else {
            return nil
        }
    }

    // Get Blueprint metadata based on NFT id
    pub fun getBlueprintByTokenId(tokenId: UInt64): Blueprint{BlueprintPublic}? {
        if self.tokenToBlueprintID.containsKey(tokenId) {
            let blueprintID: UInt64 = self.tokenToBlueprintID[tokenId]!
            return self.getBlueprint(blueprintID: blueprintID)
        } else {
            return nil 
        }
    }

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

    // The Blueprint NFT type, implements the Flow Metadata standard with views for the token URI and royalty information
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64

        pub fun getViews() : [Type] {
            return [
                Type<String>(),
                Type<{Royalties.Royalty}>()
            ]
        }

        pub fun resolveView(_ type: Type): AnyStruct {
            if type == Type<String>() {
                return Blueprints.tokenURI(tokenId: self.id)
            } else if type == Type<{Royalties.Royalty}>() {
                let metadata = Blueprints.getBlueprintByTokenId(tokenId: self.id)
                if metadata == nil {
                    panic("Token id does not correspond to a Blueprint")
                }
                return Blueprints.Royalty(metadata!.getSecondaryFeeRecipients(), metadata!.getSecondaryFeePercentages())
            } else {
                return nil
            }
        }

        init(initID: UInt64) {
            self.id = initID
        }
    }

    // Get the tokenURI for a specific NFT ID
    pub fun tokenURI(tokenId: UInt64): String {
        pre {
            self.tokenToBlueprintID.containsKey(tokenId) : "Token doesn't exist"
            self.blueprints.containsKey(self.tokenToBlueprintID[tokenId]!) : "Blueprint for token doesn't exist"
        }

        let baseURI = self.blueprints[self.tokenToBlueprintID[tokenId]!]!.baseTokenUri
        return baseURI.concat("/").concat(tokenId.toString()).concat("/token.json")
    }

    // The Bluprint NFT collection resource. Any user that wants to own, sell, etc. Blueprint NFTs needs this resource and its associated capabilities.
    // Implements the NFT standard for collections
    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {

        // A mapping of token ids to NFTs owned in this collection
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
        }

        // Borrow a metadata view resolver
        pub fun borrowViewResolver(id: UInt64): &{MetadataViews.Resolver} {
            let nft = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT
            if nft.id != id {
                panic("NFT id does not match requested id")
            }
            let blueprintNFT = nft as! &Blueprints.NFT 
            return blueprintNFT as &{MetadataViews.Resolver}
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
            let token <- token as! @Blueprints.NFT

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

    // A client resource that enables a user to interact with the sales and minting side of this contract. Any creator or individual that would like to purchase Blueprints should have this resource.
    pub resource BlueprintsClient {
        
        access(self) fun buyerWhitelistedOrSaleStarted(
            blueprintID: UInt64,
            quantity: UInt64,
            sender: Address
        ): Bool {
            // assumes blueprint with blueprintID exists by this point
            return Blueprints.blueprints[blueprintID]!.saleState == SaleState.started || 
                (Blueprints.blueprints[blueprintID]!.saleState == SaleState.notStarted && Blueprints.blueprints[blueprintID]!.isUserWhitelisted(user: sender))
        }

        access(self) fun confirmPaymentAmountAndSettleSale(
            blueprintID: UInt64,
            quantity: UInt64,
            payment: @FungibleToken.Vault,
            artist: Address
        ) {
            pre {
                UFix64(quantity) * Blueprints.blueprints[blueprintID]!.price == payment.balance : "Purchase amount must match price"
                Blueprints.isCurrencySupported(currency: payment.getType().identifier) : "Currency not whitelisted"
                payment.getType().identifier == Blueprints.blueprints[blueprintID]!.currency : "Incorrect currency"
            }
            let feeRecipients = Blueprints.blueprints[blueprintID]!.getPrimaryFeeRecipients()
            let feePercentages = Blueprints.blueprints[blueprintID]!.getPrimaryFeePercentages()
            let totalPaymentAmount: UFix64 = payment.balance
            let currency: String = payment.getType().identifier

            var feesPaid: UFix64 = 0.0 
            var i: Int = 0
            while i < feeRecipients.length {
                let amount: @FungibleToken.Vault <- payment.withdraw(amount: feePercentages[i] * totalPaymentAmount)
                feesPaid = feesPaid + amount.balance 
                Blueprints.payout(recipient: feeRecipients[i], amount: <- amount, currency: currency)

                i = i + 1
            }

            if totalPaymentAmount - feesPaid > 0.0 {
                Blueprints.payout(recipient: artist, amount: <- payment, currency: currency)
            } else {
                destroy payment
            }
        }

        access(self) fun mintQuantity(
            blueprintID: UInt64,
            quantity: UInt64,
            nftRecipient: &{NonFungibleToken.CollectionPublic}
        ) {
            pre {
                Blueprints.blueprints[blueprintID]!.capacity >= quantity : "Not enough capacity to mint quantity"
            }
            let newTokenId: UInt64 = Blueprints.blueprints[blueprintID]!.nftIndex 
            var newCap: UInt64 = Blueprints.blueprints[blueprintID]!.capacity 

            var i: UInt64 = 0
            while i < quantity {
                self.mint(recipient: nftRecipient, tokenId: newTokenId + i)
                Blueprints.tokenToBlueprintID[newTokenId + i] = blueprintID 

                let block: Block = getCurrentBlock()
                let blockHeightData: [UInt8] = block.height.toBigEndianBytes()
                let blockTimestampData: [UInt8] = block.timestamp.toBigEndianBytes()
                let blockViewData: [UInt8] = block.view.toBigEndianBytes()
                let newCapData: [UInt8] = newCap.toBigEndianBytes()
                let randomNumData: [UInt8] = unsafeRandom().toBigEndianBytes()
                let data: [UInt8] = blockHeightData.concat(blockTimestampData).concat(blockViewData).concat(newCapData).concat(randomNumData)
                let digest = HashAlgorithm.SHA3_256.hash(data)
                
                emit BlueprintMinted(
                    blueprintID: blueprintID,
                    artist: Blueprints.blueprints[blueprintID]!.artist,
                    purchaser: nftRecipient.owner!.address,
                    tokenId: newTokenId + i,
                    newCapacity: newCap,
                    seedPrefix: digest
                )

                newCap = newCap - 1
                i = i + 1
            }

            Blueprints.blueprints[blueprintID]!.updateAfterMint(_nftIndex: newTokenId + quantity, _capacity: newCap)
        }

        access(self) fun mint(
            recipient: &{NonFungibleToken.CollectionPublic},
            tokenId: UInt64
        ) {
			// create a new NFT
			var newNFT <- create NFT(initID: tokenId)

			// deposit it in the recipient's account using their reference
            // this will fail if the reference isn't to a Blueprint collection
			recipient.deposit(token: <-newNFT)
        }

        // purchases blueprints, optionally to a recipient other than resource owner
        pub fun purchaseBlueprints(
            blueprintID: UInt64,
            quantity: UInt64,
            payment: @FungibleToken.Vault,
            nftRecipient: Address
        ) {
            pre {
                self.owner != nil : "Cannot perform operation while client in transit"
                Blueprints.blueprints.containsKey(blueprintID) : "Blueprint doesn't exist"
                self.buyerWhitelistedOrSaleStarted(blueprintID: blueprintID, quantity: quantity, sender: self.owner!.address) : "Cannot purchase blueprints"
                Blueprints.blueprints[blueprintID]!.capacity >= quantity : "Quantity exceeds capacity"
                Blueprints.blueprints[blueprintID]!.maxPurchaseAmount == nil || Blueprints.blueprints[blueprintID]!.maxPurchaseAmount! >= quantity 
                    : "Cannot buy > maxPurchaseAmount in single tx" 
                getAccount(nftRecipient).getCapability<&{NonFungibleToken.CollectionPublic}>(Blueprints.collectionPublicPath).check() : "Specified receiver does not have valid public receiver collection"
            }

            let nftRecipientColRef: &{NonFungibleToken.CollectionPublic} = getAccount(nftRecipient).getCapability<&{NonFungibleToken.CollectionPublic}>(Blueprints.collectionPublicPath).borrow()!

            self.confirmPaymentAmountAndSettleSale(
                blueprintID: blueprintID,
                quantity: quantity,
                payment: <- payment,
                artist: Blueprints.blueprints[blueprintID]!.artist
            )

            if Blueprints.blueprints[blueprintID]!.saleState == SaleState.notStarted {
                Blueprints.blueprints[blueprintID]!.claimWhitelistPiece(user: self.owner!.address)
            }

            self.mintQuantity(
                blueprintID: blueprintID,
                quantity: quantity,
                nftRecipient: nftRecipientColRef
            )
        }

        // The artist or minter is allowed to mint NFTs corresponding to a specific Blueprint before its sale starts via this method
        pub fun presaleMint(
            blueprintID: UInt64,
            quantity: UInt64
        ) {
            pre {
                self.owner != nil : "Cannot perform operation while client in transit"
                Blueprints.blueprints.containsKey(blueprintID) : "Blueprint doesn't exist"
                Blueprints.blueprints[blueprintID]!.saleState == SaleState.notStarted : "Must be prepared and not started"
                Blueprints.minterAddress == self.owner!.address || Blueprints.blueprints[blueprintID]!.artist == self.owner!.address : "User cannot mint presale"
            }
            let sender: Address = self.owner!.address
            let blueprint: Blueprint = Blueprints.blueprints[blueprintID]!

            if Blueprints.minterAddress == sender {
                if quantity > blueprint.mintAmountPlatform {
                    panic("Cannot mint quantity")
                }

                Blueprints.blueprints[blueprintID]!.decrementMintAmountValues(platformDecrement: quantity, artistDecrement: 0)
            } else if blueprint.artist == sender {
                if quantity > blueprint.mintAmountArtist {
                    panic("Cannot mint quantity")
                }

                Blueprints.blueprints[blueprintID]!.decrementMintAmountValues(platformDecrement: 0, artistDecrement: quantity)
            }

            let nftRecipient: &{NonFungibleToken.CollectionPublic} = getAccount(sender).getCapability<&{NonFungibleToken.CollectionPublic}>(Blueprints.collectionPublicPath).borrow() 
                ?? panic("Sender doesn't have a public receiver for a Blueprint collection")
            self.mintQuantity(
                blueprintID: blueprintID,
                quantity: quantity,
                nftRecipient: nftRecipient
            )
        }

        // In the event that a user could not be paid royalties at the time of a purchase, the funds that could not be transferred are sent to a claims vault managed by this contract.
        // When the user is able to receive these funds, they can withdraw them with this method
        pub fun claimPayout(currency: String): @FungibleToken.Vault {
            pre {
                self.owner != nil : "Cannot perform operation while client in transit"
                Blueprints.payoutClaims[currency] != nil : "Currency type is not supported"
                Blueprints.payoutClaims[currency]![self.owner!.address] != nil : "Sender does not have any payouts to claim for this currency"
            }

            let withdrawAmount: UFix64 = Blueprints.payoutClaims[currency]![self.owner!.address]!
            let claimsVault <- Blueprints.claimsVaults.remove(key: currency)!
            let payout: @FungibleToken.Vault <- claimsVault.withdraw(amount: withdrawAmount)

            destroy <- Blueprints.claimsVaults.insert(key: currency, <- claimsVault)

            return <- payout
        }
    }

    // Public method for anyone to create a BlueprintsClient
    pub fun createBlueprintsClient(): @BlueprintsClient {
        return <- create BlueprintsClient()
    }

    // A minter resource that is owned only by an admin. This resource controls the preparaiton of new Blueprints.
	pub resource Minter {

        // Prepare a new Blueprint
        pub fun prepareBlueprint(
            _artist: Address,
            _capacity: UInt64,
            _price: UFix64,
            _currency: String,
            _blueprintMetadata: String,
            _baseTokenUri: String,
            _initialWhitelist: [Address],
            _mintAmountArtist: UInt64,
            _mintAmountPlatform: UInt64,
            _maxPurchaseAmount: UInt64? 
        ) {
            pre {
                self.owner != nil : "Cannot perform operation while client in transit"
                self.owner!.address == Blueprints.minterAddress : "Not the minter"
            }

            Blueprints.blueprints[Blueprints.blueprintIndex] = Blueprint(
                _artist: _artist,
                _capacity: _capacity,
                _price: _price,
                _currency: _currency,
                _baseTokenUri: _baseTokenUri,
                _initialWhitelist: _initialWhitelist,
                _mintAmountArtist: _mintAmountArtist,
                _mintAmountPlatform: _mintAmountPlatform,
                _blueprintMetadata: _blueprintMetadata,
                _maxPurchaseAmount: _maxPurchaseAmount
            )

            emit BlueprintPrepared(
                blueprintID: Blueprints.blueprintIndex,
                artist: _artist,
                capacity: _capacity,
                blueprintMetadata: _blueprintMetadata,
                baseTokenUri: _baseTokenUri
            )

            Blueprints.blueprintIndex = Blueprints.blueprintIndex + 1
        }

        // Update the settings for a specific Blueprint
        pub fun updateBlueprintSettings(
            _blueprintID: UInt64,
            _price: UFix64,
            _mintAmountArtist: UInt64,
            _mintAmountPlatform: UInt64,
            _newSaleState: SaleState,
            _newMaxPurchaseAmount: UInt64 
        ) {
            pre {
                self.owner != nil : "Cannot perform operation while client in transit"
                self.owner!.address == Blueprints.minterAddress : "Not the minter"
                Blueprints.blueprints.containsKey(_blueprintID) : "Blueprint doesn't exist"
            }

            Blueprints.blueprints[_blueprintID]!.updateSettings(
                _price: _price,
                _mintAmountArtist: _mintAmountArtist,
                _mintAmountPlatform: _mintAmountPlatform,
                _newSaleState: _newSaleState,
                _newMaxPurchaseAmount: _newMaxPurchaseAmount 
            )

            emit BlueprintSettingsUpdated(
                blueprintID: _blueprintID,
                price: _price,
                newMintAmountArtist: _mintAmountArtist,
                newMintAmountPlatform: _mintAmountPlatform,
                newSaleState: _newSaleState.rawValue,
                newMaxPurchaseAmount: _newMaxPurchaseAmount 
            )
        }

        // Add specific addresses to the whitelist for a Blueprint
        pub fun addToBlueprintWhitelist(
            _blueprintID: UInt64,
            _whitelistAdditions: [Address]
        ) {
            pre {
                self.owner != nil : "Cannot perform operation while client in transit"
                self.owner!.address == Blueprints.minterAddress : "Not the minter"
                Blueprints.blueprints.containsKey(_blueprintID) : "Blueprint doesn't exist"
            }

            let oldWhitelist: {Address: Bool} = Blueprints.blueprints[_blueprintID]!.whitelist
            Blueprints.blueprints[_blueprintID]!.addToWhitelist(_whitelistAdditions: _whitelistAdditions)
        
            emit BlueprintWhitelistUpdated(
                blueprintID: _blueprintID,
                oldWhitelist: oldWhitelist,
                newWhitelist: Blueprints.blueprints[_blueprintID]!.whitelist
            )
        }

        // Remove specific addreses from the whitelist for a Blueprint
        pub fun removeBlueprintWhitelist(
            _blueprintID: UInt64,
            _whitelistRemovals: [Address]
        ) {
            pre {
                self.owner != nil : "Cannot perform operation while client in transit"
                self.owner!.address == Blueprints.minterAddress : "Not the minter"
                Blueprints.blueprints.containsKey(_blueprintID) : "Blueprint doesn't exist"
            }

            let oldWhitelist: {Address: Bool} = Blueprints.blueprints[_blueprintID]!.whitelist
            Blueprints.blueprints[_blueprintID]!.removeFromWhitelist(_whitelistRemovals: _whitelistRemovals)
        
            emit BlueprintWhitelistUpdated(
                blueprintID: _blueprintID,
                oldWhitelist: oldWhitelist,
                newWhitelist: Blueprints.blueprints[_blueprintID]!.whitelist
            )
        }

        // Overwrite the whitelist of a Blueprint
        pub fun overwriteBlueprintWhitelist(
            _blueprintID: UInt64,
            _whitelistedAddresses: [Address]
        ) {
            pre {
                self.owner != nil : "Cannot perform operation while client in transit"
                self.owner!.address == Blueprints.minterAddress : "Not the minter"
                Blueprints.blueprints.containsKey(_blueprintID) : "Blueprint doesn't exist"
            }

            let oldWhitelist: {Address: Bool} = Blueprints.blueprints[_blueprintID]!.whitelist
            Blueprints.blueprints[_blueprintID]!.overwriteWhitelist(_whitelistedAddresses: _whitelistedAddresses)
        
            emit BlueprintWhitelistUpdated(
                blueprintID: _blueprintID,
                oldWhitelist: oldWhitelist,
                newWhitelist: Blueprints.blueprints[_blueprintID]!.whitelist
            )
        }

        // Update the fee recipients of a Blueprint
        pub fun setFeeRecipients(
            _blueprintID: UInt64,
            _primaryFeeRecipients: [Address],
            _primaryFeePercentages: [UFix64],
            _secondaryFeeRecipients: [Address],
            _secondaryFeePercentages: [UFix64]
        ) {
            pre {
                self.owner != nil : "Cannot perform operation while client in transit"
                self.owner!.address == Blueprints.minterAddress : "Not the minter"
                Blueprints.blueprints.containsKey(_blueprintID) : "Blueprint doesn't exist"
            }

            Blueprints.blueprints[_blueprintID]!.setFeeRecipients(
                _primaryFeeRecipients: _primaryFeeRecipients, 
                _primaryFeePercentages: _primaryFeePercentages, 
                _secondaryFeeRecipients: _secondaryFeeRecipients, 
                _secondaryFeePercentages: _secondaryFeePercentages
            )
        }

        // Change the state of a Blueprint to sale started: enabling the public to purchase Blueprints with this ID.
        pub fun beginSale(_blueprintID: UInt64) {
            pre {
                self.owner != nil : "Cannot perform operation while client in transit"
                self.owner!.address == Blueprints.minterAddress : "Not the minter"
                Blueprints.blueprints.containsKey(_blueprintID) : "Blueprint doesn't exist"
                Blueprints.blueprints[_blueprintID]!.saleState == SaleState.notStarted : "Sale not not started"
            }

            Blueprints.blueprints[_blueprintID]!.setSaleState(state: SaleState.started)

            emit SaleStarted(blueprintID: _blueprintID)
        }

        // Pause the sale for a Blueprint. This will stop the public from being able to purchase Blueprints for this ID.
        pub fun pauseSale(_blueprintID: UInt64) {
            pre {
                self.owner != nil : "Cannot perform operation while client in transit"
                self.owner!.address == Blueprints.minterAddress : "Not the minter"
                Blueprints.blueprints.containsKey(_blueprintID) : "Blueprint doesn't exist"
                Blueprints.blueprints[_blueprintID]!.saleState == SaleState.started : "Sale not started"
            }

            Blueprints.blueprints[_blueprintID]!.setSaleState(state: SaleState.paused)

            emit SalePaused(blueprintID: _blueprintID)
        }

        // Unpause a paused Blueprint sale
        pub fun unpauseSale(_blueprintID: UInt64) {
            pre {
                self.owner != nil : "Cannot perform operation while client in transit"
                self.owner!.address == Blueprints.minterAddress : "Not the minter"
                Blueprints.blueprints.containsKey(_blueprintID) : "Blueprint doesn't exist"
                Blueprints.blueprints[_blueprintID]!.saleState == SaleState.paused : "Sale not paused"
            }

            Blueprints.blueprints[_blueprintID]!.setSaleState(state: SaleState.started)

            emit SaleUnpaused(blueprintID: _blueprintID)
        }

        // update a blueprint's token uri
        pub fun updateBlueprintTokenUri(
            blueprintID: UInt64,
            newBaseTokenUri: String
        ) {
            pre {
                self.owner != nil : "Cannot perform operation while client in transit"
                self.owner!.address == Blueprints.minterAddress : "Not the minter"
                Blueprints.blueprints.containsKey(blueprintID) : "Blueprint doesn't exist"
                !Blueprints.blueprints[blueprintID]!.tokenUriLocked : "Blueprint URI locked"
            }

            Blueprints.blueprints[blueprintID]!.updateBaseTokenUri(newBaseTokenUri: newBaseTokenUri)
            emit BlueprintTokenUriUpdated(
                blueprintID: blueprintID,
                newBaseTokenUri: newBaseTokenUri
            )
        }

        // Reveal the seed associated with a specific Blueprint
        pub fun revealBlueprintSeed(
            blueprintID: UInt64,
            randomSeed: String
        ) {
            pre {
                self.owner != nil : "Cannot perform operation while client in transit"
                self.owner!.address == Blueprints.minterAddress : "Not the minter"
                Blueprints.blueprints.containsKey(blueprintID) : "Blueprint doesn't exist"
            }

            emit BlueprintSeed(
                blueprintID: blueprintID,
                randomSeed: randomSeed
            )
        }
	}

    // A function to create a minter resource
    // @notice this contract has a variable 'minterAddress' which is only settable by the "Platform"
    //         'minterAddress' is the only address who's Minter resource function calls will change contract state
    //          hence, even though anyone can create this 'admin' resource it is useless unless they are 'minterAddress'
    pub fun createMinter(): @Minter {
        return <- create Minter()
    }

    // An admin resource that manages the minter and other governance variables
    pub resource Platform {
        pub fun changeMinter(newMinter: Address) {
            Blueprints.minterAddress = newMinter
        }

        pub fun lockBlueprintTokenUri(blueprintID: UInt64) {
            pre {
                Blueprints.blueprints.containsKey(blueprintID) : "Blueprint doesn't exist"
                !Blueprints.blueprints[blueprintID]!.tokenUriLocked : "Blueprint URI locked"
            }

            Blueprints.blueprints[blueprintID]!.lockTokenUri()
        }

        pub fun setAsyncFeeRecipient(_asyncSalesFeeRecipient: Address) {
            Blueprints.asyncSaleFeesRecipient = _asyncSalesFeeRecipient
        }

        pub fun changeDefaultPlatformPrimaryFeePercentage(newFee: UFix64) {
            pre {
                newFee <= 1.0 : "Invalid fee"
            }
            Blueprints.defaultPlatformPrimaryFeePercentage = newFee
        }

        pub fun changeDefaultPlatformSecondaryFeePercentage(newFee: UFix64) {
            pre {
                newFee + Blueprints.defaultBlueprintSecondarySalePercentage <= 1.0 : "Invalid fee"
            }
            Blueprints.defaultPlatformSecondarySalePercentage = newFee
        }

        pub fun changeDefaultBlueprintSecondaryFeePercentage(newFee: UFix64) {
            pre {
                newFee + Blueprints.defaultPlatformSecondarySalePercentage <= 1.0 : "Invalid fee"
            }
            Blueprints.defaultBlueprintSecondarySalePercentage = newFee
        }

        // whitelist currency
        pub fun whitelistCurrency(
            currency: String,
            currencyPublicPath: PublicPath,
            currencyPrivatePath: PrivatePath,
            currencyStoragePath: StoragePath,
            vault: @FungibleToken.Vault
        ) {
            pre {
                Blueprints.isValidCurrencyFormat(_currency: currency) : "Currency identifier is invalid"
                !Blueprints.isCurrencySupported(currency: currency): "Currency is already whitelisted"
            }

            post {
                Blueprints.isCurrencySupported(currency: currency): "Currency not whitelisted successfully"
            }

            Blueprints.currencyPaths[currency] = Paths(
                currencyPublicPath,
                currencyPrivatePath,
                currencyStoragePath
            )
            Blueprints.payoutClaims.insert(key: currency, {})
            destroy <- Blueprints.claimsVaults.insert(key: currency, <- vault)

            emit CurrencyWhitelisted(currency: currency)
        }

        // unwhitelist currency safe (checks if claims vault being removed is empty)
        pub fun unwhitelistCurrencySafe(
            currency: String
        ) {
            pre {
                Blueprints.isCurrencySupported(currency: currency): "Currency is not whitelisted"
            }

            post {
                !Blueprints.isCurrencySupported(currency: currency): "Currency unwhitelist failed"
            }

            Blueprints.currencyPaths.remove(key: currency)
            Blueprints.payoutClaims.remove(key: currency)

            let vault <- Blueprints.claimsVaults.remove(key: currency) ?? panic("Could not retrieve claims vault for currency")
            if vault.balance > 0.0 {
                panic("Claims vault is non-empty")
            }
            destroy vault

            emit CurrencyUnwhitelisted(currency: currency)
        }

        // unwhitelist currency unchecked (doesn't check if claims vault being removed is empty)
        pub fun unwhitelistCurrencyUnchecked(
            currency: String
        ) {
            pre {
                Blueprints.isCurrencySupported(currency: currency): "Currency is not whitelisted"
            }

            post {
                !Blueprints.isCurrencySupported(currency: currency): "Currency unwhitelist failed"
            }

            Blueprints.currencyPaths.remove(key: currency)
            Blueprints.payoutClaims.remove(key: currency)

            // Warning this could permanently remove funds from claims -- but claims is already quite accomodating so we won't block
            // admin if the claims vault is non-empty
            let vault <- Blueprints.claimsVaults.remove(key: currency) ?? panic("Could not retrieve claims vault for currency")

            // if any remaining, pay out to asyncSaleFeesRecipient to potentially manually payout later
            Blueprints.payout(recipient: Blueprints.asyncSaleFeesRecipient, amount: <- vault, currency: currency)

            emit CurrencyUnwhitelisted(currency: currency)
        }
    }

	init(minterAddress: Address, flowTokenCurrencyType: String, fusdCurrencyType: String) {
        // Initialize the total supply
        self.totalSupply = 0

        self.collectionStoragePath = /storage/BlueprintCollection
        self.collectionPrivatePath = /private/BlueprintCollection
        self.collectionPublicPath = /public/BlueprintCollection
        self.collectionMetadataViewResolverPublicPath = /public/BlueprintMetadataViews
        self.minterStoragePath = /storage/BlueprintMinter
        self.platformStoragePath = /storage/BlueprintPlatform
        self.blueprintsClientStoragePath = /storage/BlueprintClient

        self.minterAddress = minterAddress
        self.blueprintIndex = 0
        self.latestNftIndex = 0

        self.defaultPlatformPrimaryFeePercentage = 0.2
        self.defaultBlueprintSecondarySalePercentage = 0.075
        self.defaultPlatformSecondarySalePercentage = 0.025
        self.asyncSaleFeesRecipient = self.account.address

        self.blueprints = {}
        self.tokenToBlueprintID = {}

        // whitelist flowToken and fusd to start
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

        let collection <- self.createEmptyCollection()
        self.account.save(<- collection, to: self.collectionStoragePath)

        self.account.link<&Blueprints.Collection{NonFungibleToken.Provider}>(
            self.collectionPrivatePath,
            target: self.collectionStoragePath
        )

        self.account.link<&Blueprints.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver}>(
            Blueprints.collectionPublicPath,
            target: Blueprints.collectionStoragePath
        )

        // Create a Minter resource and save it to storage (even if minter is not deploying account)
        let minter <- self.createMinter()
        self.account.save(<- minter, to: self.minterStoragePath)

        // Create a Platform resource and save it to storage
        let platform <- create Platform()
        self.account.save(<-platform, to: self.platformStoragePath)

        // Create a BlueprintsClient resource and save it to storage
        let blueprintsClient <- create BlueprintsClient()
        self.account.save(<-blueprintsClient, to: self.blueprintsClientStoragePath)

        emit ContractInitialized()
	}
}