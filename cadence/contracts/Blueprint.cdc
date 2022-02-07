// Blueprint

import NonFungibleToken from "./NonFungibleToken.cdc"

pub contract Blueprints: NonFungibleToken {
    pub var collectionStoragePath: StoragePath
    pub var collectionPrivatePath: PrivatePath
    pub var collectionPublicPath: PublicPath
    pub var minterStoragePath: StoragePath
    pub var platformStoragePath: StoragePath

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

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub event BlueprintPrepared(
        blueprintID: UInt64,
        artist: Address,
        capacity: UInt64,
        blueprintMetadata: String,
        baseTokenUri: String
    )

    pub enum SaleState: UInt8 {
        pub case notPrepared
        pub case notStarted 
        pub case started 
        pub case paused
    }

    pub struct Blueprint {
        pub var tokenUriLocked: Bool
        pub var mintAmountArtist: UInt64 
        pub var mintAmountPlatform: UInt64 
        pub var capacity: UInt64 
        pub var nftIndex: UInt64 
        pub var maxPurchaseAmount: UInt64 
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

        init(
            _artist: Address,
            _capacity: UInt64,
            _price: UFix64,
            _currency: String,
            _baseTokenUri: String,
            _initialWhitelist: {Address: Bool},
            _mintAmountArtist: UInt64,
            _mintAmountPlatform: UInt64,
            _maxPurchaseAmount: UInt64,
            _blueprintMetadata: String
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
            self.whitelist = _initialWhitelist
            self.mintAmountArtist = _mintAmountArtist
            self.mintAmountPlatform = _mintAmountPlatform
            self.maxPurchaseAmount = _maxPurchaseAmount
            self.blueprintMetadata = _blueprintMetadata

            Blueprints.latestNftIndex = Blueprints.latestNftIndex + _capacity
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

    pub resource NFT: NonFungibleToken.INFT {
        pub let id: UInt64

        pub var metadata: {String: String}

        init(initID: UInt64) {
            self.id = initID
            self.metadata = {}
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

    // Resource that an admin or something similar would own to be
    // able to mint new NFTs
    //
	pub resource NFTMinter {
        // setup blueprint
        pub fun prepareBlueprint(
            _artist: Address,
            _capacity: UInt64,
            _price: UFix64,
            _currency: String,
            _blueprintMetadata: String,
            _baseTokenUri: String,
            _initialWhitelist: {Address: Bool},
            _mintAmountArtist: UInt64,
            _mintAmountPlatform: UInt64,
            _maxPurchaseAmount: UInt64 
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
                _maxPurchaseAmount: _maxPurchaseAmount,
                _blueprintMetadata: _blueprintMetadata
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

            Blueprints.blueprints[_blueprintID]!.updateBlueprintSettings(
                
            )
        }

        pub fun addToBlueprintWhitelist(
            
        ) {
            pre {
                self.owner != nil : "Cannot perform operation while client in transit"
                self.owner!.address == Blueprints.minterAddress : "Not the minter"
            }
        }

        pub fun overwriteBlueprintWhitelist(
             
        ) {
            pre {
                self.owner != nil : "Cannot perform operation while client in transit"
                self.owner!.address == Blueprints.minterAddress : "Not the minter"
            }

        }

        /*
		// mintNFT mints a new NFT with a new ID
		// and deposit it in the recipients collection using their collection reference
		pub fun mintNFT(recipient: &{NonFungibleToken.CollectionPublic}) {
            pre {
                self.owner != nil : "Cannot perform operation while client in transit"
                self.owner!.address == Blueprint.minterAddress : "Not the minter"
            }
			// create a new NFT
			var newNFT <- create NFT(initID: Blueprint.totalSupply)

			// deposit it in the recipient's account using their reference
			recipient.deposit(token: <-newNFT)

            Blueprint.totalSupply = Blueprint.totalSupply + (1 as UInt64)
		}
        */
	}

    pub fun createMinter(): @NFTMinter {
        return <- create NFTMinter()
    }

    pub resource Platform {
        // change minter
        pub fun changeMinter(newMinter: Address) {
            Blueprints.minterAddress = newMinter
        }
    }

	init(minter: Address) {
        // Initialize the total supply
        self.totalSupply = 0

        self.collectionStoragePath = /storage/BlueprintCollection
        self.collectionPrivatePath = /private/BlueprintCollection
        self.collectionPublicPath = /public/BlueprintCollection
        self.minterStoragePath = /storage/BlueprintMinter
        self.platformStoragePath = /storage/BlueprintPlatform

        self.minterAddress = minter
        self.blueprintIndex = 0
        self.latestNftIndex = 0

        self.defaultPlatformPrimaryFeePercentage = 20.0
        self.defaultBlueprintSecondarySalePercentage = 7.5
        self.defaultPlatformSecondarySalePercentage = 2.5
        self.asyncSaleFeesRecipient = self.account.address

        // Create a Minter resource and save it to storage (even if minter is not deploying account)
        let minter <- create NFTMinter()
        self.account.save(<- minter, to: self.minterStoragePath)

        // Create a Platform resource and save it to storage
        let platform <- create Platform()
        self.account.save(<-platform, to: self.platformStoragePath)

        emit ContractInitialized()
	}
}