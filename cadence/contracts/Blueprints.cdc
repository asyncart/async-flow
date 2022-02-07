import NonFungibleToken from "./NonFungibleToken.cdc"
import FungibleToken from "./FungibleToken.cdc"
import FlowToken from "./FlowToken.cdc"
import FUSD from "./FUSD.cdc"

pub contract Blueprints: NonFungibleToken {
    pub var collectionStoragePath: StoragePath
    pub var collectionPrivatePath: PrivatePath
    pub var collectionPublicPath: PublicPath
    pub var minterStoragePath: StoragePath
    pub var platformStoragePath: StoragePath
    pub var blueprintsClientStoragePath: StoragePath

    pub var totalSupply: UInt64

    pub var defaultPlatformPrimaryFeePercentage: UFix64
    pub var defaultBlueprintSecondarySalePercentage: UFix64
    pub var defaultPlatformSecondarySalePercentage: UFix64
    pub var latestNftIndex: UInt64
    pub var blueprintIndex: UInt64

    pub var asyncSaleFeesRecipient: Address
    access(self) var minterAddress: Address

    // token id to blueprint id
    access(self) let tokenToBlueprintID: {UInt64: UInt64}
    access(self) let blueprints: {UInt64: Blueprint}

    // A mapping of currency type identifiers to expected paths
    access(self) let currencyPaths: {String: Paths}

    // managing claims on failed payouts

    // A mapping of currency type identifiers to intermediary claims vaults
    access(self) let claimsVaults: @{String: FungibleToken.Vault}

    // A mapping of currency type identifiers to {User Addresses -> Amounts of currency they are owed}
    access(self) let payoutClaims: {String: {Address: UFix64}}

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub event BlueprintSeed(
        blueprintID: UInt64,
        randomSeed: String
    )

    pub event BlueprintPrepared(
        blueprintID: UInt64,
        artist: Address,
        capacity: UInt64,
        blueprintMetadata: String,
        baseTokenUri: String
    )

    pub event BlueprintSettingsUpdated(
        blueprintID: UInt64,
        price: UFix64,
        newMintAmountArtist: UInt64,
        newMintAmountPlatform: UInt64,
        newSaleState: UInt8,
        newMaxPurchaseAmount: UInt64 
    )
    
    pub event BlueprintWhitelistUpdated(
        oldWhitelist: {Address: Bool},
        newWhitelist: {Address: Bool}
    )

    pub event SaleStarted(blueprintID: UInt64)

    pub event SalePaused(blueprintID: UInt64)

    pub event SaleUnpaused(blueprintID: UInt64)

    pub event BlueprintTokenUriUpdated(
        blueprintID: UInt64,
        newBaseTokenUri: String
    )

    pub event CurrencyWhitelisted(currency: String)

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

    pub enum SaleState: UInt8 {
        pub case notStarted 
        pub case started 
        pub case paused
    }

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
        pub var primaryFeePercentages: [UFix64]
        pub var secondaryFeePercentages: [UFix64]
        pub var primaryFeeRecipients: [Address]
        pub var secondaryFeeRecipients: [Address]
    }

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
        pub var primaryFeePercentages: [UFix64]
        pub var secondaryFeePercentages: [UFix64]
        pub var primaryFeeRecipients: [Address]
        pub var secondaryFeeRecipients: [Address]

        // maps whitelisted addresses to if they've claimed
        pub var whitelist: {Address: Bool}

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
            for newAddress in _whitelistAdditions {
                if !self.whitelist.containsKey(newAddress) {
                    self.whitelist.insert(key: newAddress, false)
                }
            }
        }

        pub fun removeFromWhitelist(
            _whitelistRemovals: [Address]
        ) {
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
            if _feeRecipients.length != 0 || _feePercentages.length != 0 {
                if _feeRecipients.length != _feePercentages.length {
                    return false 
                }

                var totalPercent: UFix64 = 0.0 
                for percentage in _feePercentages {
                    totalPercent = totalPercent + percentage 
                }
                if totalPercent > 100.0 {
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
            self.maxPurchaseAmount = _maxPurchaseAmount != nil ? _maxPurchaseAmount : nil
            self.blueprintMetadata = _blueprintMetadata

            self.whitelist = {}
            self.addToWhitelist(_whitelistAdditions: _initialWhitelist)

            Blueprints.latestNftIndex = Blueprints.latestNftIndex + _capacity
        }
    }

    pub fun getBlueprints(): [Blueprint{BlueprintPublic}] {
        return self.blueprints.values
    }

    pub fun getBlueprint(blueprintID: UInt64): Blueprint{BlueprintPublic}? {
        if self.blueprints.containsKey(blueprintID) {
            return self.blueprints[blueprintID]!
        } else {
            return nil
        }
    }

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

    pub resource interface ViewResolver {
        pub fun getViews() : [Type]
        pub fun resolveView(_ view:Type): AnyStruct?    
    }

    pub resource NFT: NonFungibleToken.INFT, ViewResolver {
        pub let id: UInt64

        pub fun getViews() : [Type] {
            return [
                Type<String>()
            ]
        }

        pub fun resolveView(_ type: Type): AnyStruct {
            if type == Type<String>() {
                return Blueprints.tokenURI(tokenId: self.id)
            } else {
                return nil
            }
        }

        init(initID: UInt64) {
            self.id = initID
        }
    }

    pub fun tokenURI(tokenId: UInt64): String {
        pre {
            self.tokenToBlueprintID.containsKey(tokenId) : "Token doesn't exist"
            self.blueprints.containsKey(self.tokenToBlueprintID[tokenId]!) : "Blueprint for token doesn't exist"
        }

        let baseURI = self.blueprints[self.tokenToBlueprintID[tokenId]!]!.baseTokenUri
        return baseURI.concat("/").concat(tokenId.toString()).concat("/token.json")
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

    pub resource BlueprintsClient {
        // checks if the buyer is whitelisted or the sale has started
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
                Blueprints.currencyPaths.containsKey(payment.getType().identifier) : "Currency not whitelisted"
                Blueprints.claimsVaults.containsKey(payment.getType().identifier) : "Currency not whitelisted"
            }
            let feeRecipients = Blueprints.blueprints[blueprintID]!.primaryFeeRecipients 
            let feePercentages = Blueprints.blueprints[blueprintID]!.primaryFeePercentages
            let totalPaymentAmount: UFix64 = payment.balance
            let currency: String = payment.getType().identifier

            var feesPaid: UFix64 = 0.0 
            var i: Int = 0
            while i < feeRecipients.length {
                let amount: @FungibleToken.Vault <- payment.withdraw(amount: feePercentages[i] * totalPaymentAmount)
                feesPaid = feesPaid + amount.balance 
                self.payout(recipient: feeRecipients[i], amount: <- amount, currency: currency)

                i = i + 1
            }

            if totalPaymentAmount - feesPaid > 0.0 {
                self.payout(recipient: artist, amount: <- payment, currency: currency)
            } else {
                destroy payment
            }
        }

        access(self) fun payout(
            recipient: Address,
            amount: @FungibleToken.Vault,
            currency: String
        ) {
            let receiverPath = Blueprints.currencyPaths[currency]!.public
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
            if Blueprints.payoutClaims[currency]![recipient] == nil {
                newClaim = amount.balance
            } else {
                newClaim = Blueprints.payoutClaims[currency]![recipient]! + amount.balance
            }
            Blueprints.payoutClaims[currency]!.insert(key: recipient, newClaim)

            let claimsVault <- Blueprints.claimsVaults.remove(key: currency)!
            claimsVault.deposit(from: <- amount)

            destroy <- Blueprints.claimsVaults.insert(key: currency, <- claimsVault)
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

                // generate prefixHash
                // emit event

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
            nftRecipient: &{NonFungibleToken.CollectionPublic}
        ) {
            pre {
                self.owner != nil : "Cannot perform operation while client in transit"
                Blueprints.blueprints.containsKey(blueprintID) : "Blueprint doesn't exist"
                self.buyerWhitelistedOrSaleStarted(blueprintID: blueprintID, quantity: quantity, sender: self.owner!.address) : "Cannot purchase blueprints"
                Blueprints.blueprints[blueprintID]!.capacity >= quantity : "Quantity exceeds capacity"
                Blueprints.blueprints[blueprintID]!.maxPurchaseAmount == nil || Blueprints.blueprints[blueprintID]!.maxPurchaseAmount! >= quantity 
                    : "Cannot buy > maxPurchaseAmount in single tx" 
            }

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
                nftRecipient: nftRecipient!
            )
        }

        // presale mint
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
                ?? panic("Sender doesn't have a public receiver for a  Blueprint collection")
            self.mintQuantity(
                blueprintID: blueprintID,
                quantity: quantity,
                nftRecipient: nftRecipient
            )
        }

        // claim amount
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

    pub fun createBlueprintsClient(): @BlueprintsClient {
        return <- create BlueprintsClient()
    }

    // Resource that an admin or something similar would own to be
    // able to mint new NFTs
    //
	pub resource Minter {
        // setup blueprint
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

        // update blueprint settings
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

        // add to blueprint whitelist
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
                oldWhitelist: oldWhitelist,
                newWhitelist: Blueprints.blueprints[_blueprintID]!.whitelist
            )
        }

        // remove blueprint whitelist
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
                oldWhitelist: oldWhitelist,
                newWhitelist: Blueprints.blueprints[_blueprintID]!.whitelist
            )
        }

        // overwrite blueprint whitelist
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
                oldWhitelist: oldWhitelist,
                newWhitelist: Blueprints.blueprints[_blueprintID]!.whitelist
            )
        }

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

        pub fun revealBlueprintSeed(
            blueprintID: UInt64,
            randomSeed: String
        ) {
            pre {
                Blueprints.blueprints.containsKey(blueprintID) : "Blueprint doesn't exist"
            }

            emit BlueprintSeed(
                blueprintID: blueprintID,
                randomSeed: randomSeed
            )
        }
	}

    pub fun createMinter(): @Minter {
        return <- create Minter()
    }

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
                newFee <= 100.0 : "Invalid fee"
            }
            Blueprints.defaultPlatformPrimaryFeePercentage = newFee
        }

        pub fun changeDefaultPlatformSecondaryFeePercentage(newFee: UFix64) {
            pre {
                newFee + Blueprints.defaultBlueprintSecondarySalePercentage <= 100.0 : "Invalid fee"
            }
            Blueprints.defaultPlatformSecondarySalePercentage = newFee
        }

        pub fun changeDefaultBlueprintSecondaryFeePercentage(newFee: UFix64) {
            pre {
                newFee + Blueprints.defaultPlatformSecondarySalePercentage <= 100.0 : "Invalid fee"
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
                !Blueprints.currencyPaths.containsKey(currency) : "Currency already whitelisted"
                !Blueprints.claimsVaults.containsKey(currency) : "Currency already whitelisted"
                !Blueprints.payoutClaims.containsKey(currency) : "Currency already whitelisted"
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
    }

	init(minter: Address, flowTokenCurrencyType: String, fusdCurrencyType: String) {
        // Initialize the total supply
        self.totalSupply = 0

        self.collectionStoragePath = /storage/BlueprintCollection
        self.collectionPrivatePath = /private/BlueprintCollection
        self.collectionPublicPath = /public/BlueprintCollection
        self.minterStoragePath = /storage/BlueprintMinter
        self.platformStoragePath = /storage/BlueprintPlatform
        self.blueprintsClientStoragePath = /storage/BlueprintClient

        self.minterAddress = minter
        self.blueprintIndex = 0
        self.latestNftIndex = 0

        self.defaultPlatformPrimaryFeePercentage = 20.0
        self.defaultBlueprintSecondarySalePercentage = 7.5
        self.defaultPlatformSecondarySalePercentage = 2.5
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
                /private/flowTokenVault, // technically unknown standard
                /storage/flowTokenVault
            ),
            fusdCurrencyType: Paths(
                /public/fusdReceiver,
                /private/fusdVault, // technically unknown standard
                /storage/fusdVault
            )
        }
        self.payoutClaims = {
            flowTokenCurrencyType: {},
            fusdCurrencyType: {}
        }

        // Create a Minter resource and save it to storage (even if minter is not deploying account)
        let minter <- create Minter()
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