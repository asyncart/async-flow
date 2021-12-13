import NonFungibleToken from "./NonFungibleToken.cdc"

pub contract AsyncArtwork: NonFungibleToken {
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub var totalSupply: UInt64
    pub var collectionStoragePath: StoragePath 
    pub var collectionPublicPath: PublicPath
    pub var stateStoragePath: StoragePath
    pub var asyncUserStoragePath: StoragePath 
    pub var asyncUserPrivatePath: PrivatePath 
    pub var asyncUserPublicPath: PublicPath

    pub resource AsyncUser {
        pub let id: UInt64

        init(id: UInt64) {
            self.id = id
        }
    }

    pub fun createAsyncUser(): @AsyncUser {
        let state = self.account.borrow<&AsyncState>(from: self.stateStoragePath) ?? panic("Could not borrow reference to state")

        return <- state.createAsyncUser()
    }

    pub resource AsyncState {
        pub var totalUsers: UInt64 

        pub fun createAsyncUser(): @AsyncUser {
            self.totalUsers = self.totalUsers + (1 as UInt64)
            return <- create AsyncUser(id: self.totalUsers)
        }

        init() {
            self.totalUsers = 0
        }
    }

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

    // mintNFT mints a new NFT with a new ID
    // and deposit it in the recipients collection using their collection reference
    pub fun setupControlToken(
        recipient: &{NonFungibleToken.CollectionPublic}, 
        tokenUri: String, 
        leverMinValues: [Int64], 
        leverMaxValues: [Int64], 
        leverStartValues: [Int64], 
        numAllowedUpdates: Int64
    ) {
        pre {
            leverMaxValues.length <= 500 : "Too many control levers."
            leverMaxValues.length == leverMinValues.length && leverStartValues.length == leverMaxValues.length : "Values array mismatch"
            numAllowedUpdates == -1 || numAllowedUpdates > 0 : "Invalid allowed updates"
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

	init() {
        self.collectionStoragePath = /storage/AsyncArtworkNFTCollection
        self.collectionPublicPath = /public/AsyncArtworkCollection

        // Initialize the total supply
        self.totalSupply = 0

        self.stateStoragePath = /storage/AsyncState
        self.asyncUserStoragePath = /storage/AsyncUser 
        self.asyncUserPrivatePath = /private/AsyncUser
        self.asyncUserPublicPath = /public/AsyncUser

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.save(<-collection, to: self.collectionStoragePath)

        // create a public capability for the collection
        self.account.link<&{NonFungibleToken.CollectionPublic}>(
            self.collectionPublicPath,
            target: self.collectionStoragePath
        )

        let state <- create AsyncState()
        self.account.save(<- state, to: self.stateStoragePath)

        emit ContractInitialized()
	}
}
 