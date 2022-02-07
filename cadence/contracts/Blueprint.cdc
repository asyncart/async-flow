// Blueprint

import NonFungibleToken from "./NonFungibleToken.cdc"

pub contract Blueprint: NonFungibleToken {
    pub var collectionStoragePath: StoragePath
    pub var collectionPrivatePath: PrivatePath
    pub var collectionPublicPath: PublicPath
    pub var minterStoragePath: StoragePath
    pub var platformStoragePath: StoragePath

    pub var totalSupply: UInt64

    pub var defaultPlatformPrimaryFeePercentage: UFix64
    pub var defaultBlueprintSecondarySalePercentage: UFix64
    pub var defaultPlatformSecondarySalePercentage: UFix64
    pub var latestTokenIndex: UInt64
    pub var blueprintIndex: UInt64

    pub var asyncSaleFeesRecipient: Address
    access(self) var minterAddress: Address

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

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
            let token <- token as! @Blueprint.NFT

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
	}

    pub fun createMinter(): @NFTMinter {
        return <- create NFTMinter()
    }

    pub resource Platform {
        // change minter
        pub fun changeMinter(newMinter: Address) {
            Blueprint.minterAddress = newMinter
        }
    }

	init() {
        // Initialize the total supply
        self.totalSupply = 0

        self.collectionStoragePath = /storage/BlueprintCollection
        self.collectionPrivatePath = /private/BlueprintCollection
        self.collectionPublicPath = /public/BlueprintCollection
        self.minterStoragePath = /storage/BlueprintMinter
        self.platformStoragePath = /storage/BlueprintPlatform

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.save(<-collection, to: /storage/BlueprintCollection)

        // create a public capability for the collection
        self.account.link<&{NonFungibleToken.CollectionPublic}>(
            /public/BlueprintCollection,
            target: /storage/BlueprintCollection
        )

        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.save(<-minter, to: Blueprint.minterStoragePath)

        let platform <- create Platform()
        self.account.save(<-platform, to: Blueprint.platformStoragePath)

        emit ContractInitialized()
	}
}