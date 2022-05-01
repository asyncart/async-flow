import FungibleToken from "./FungibleToken.cdc"

// FungibleTokenSwitchboard
//
// A contract that provides a Fungible Token receiver that can receive different FTs
// and send them to the correct Vault. Slightly modified by Ishan Ghimire, Sam Orend.
//
pub contract FungibleTokenSwitchboard {

    // Event that is emitted when tokens are deposited to the target receiver.
    pub event TokensDispatched(type: Type, amount: UFix64, via: Address?)

    // Path to store a Switchboard in a user's storage
    pub let SwitchboardStoragePath: StoragePath
    // Path to store a public capability to the switchboard
    pub let SwitchboardPublicPath: PublicPath
    // Path to store a private capability to the switchboard
    pub let SwitchboardPrivatePath: PrivatePath

    // For the resource owner to change which tokens the forwarder accepts.
    // This should at most be linked as a private capability, and must not be publicly exposed.
    // This is mostly future-proofing.
    //
    pub resource interface SwitchboardAdmin {
        pub fun setVaultRecipient(_ newRecipient: Capability<&{FungibleToken.Receiver}>, vaultType: Type)
        pub fun removeVaultRecipient(vaultType: Type)
    }

    // To allow public access to information that callers of the forwarder might need
    //
    pub resource interface SwitchboardPublic {
        pub fun acceptsVault(type: Type): Bool
        //FIXME: if possible, remove acceptsVaultTypeIdentifiers and uncomment acceptsVaultTypes
        //pub fun acceptsVaultTypes(): [Type]
        pub fun acceptsVaultTypeIdentifiers(): [String]
    }

    // NOTE: Create a public capability of the FungibleToken.Receiver constrained to <&FungibleToken.Receiver, &SwitchboardPublic>
    // The user does not *have* to do this, but should not create a separate capability to the Public interface.
    // This is to avoid creating too many different paths for a single resource type, and to make the forwarder look as much like a standard
    // reciver as possible while still making it easy to access information specific to the forwarder.
    pub resource Switchboard: FungibleToken.Receiver, SwitchboardAdmin, SwitchboardPublic {
        // The Fungible Token types that we accept, and their receivers.
        // Note that we cannot use Type as a key yet.
        access(self) let recipients: {String: Capability<&{FungibleToken.Receiver}>}

        // deposit
        //
        // Function that takes a Vault object as an argument and forwards
        // it to the recipient's Vault using the stored reference.
        //
        pub fun deposit(from: @FungibleToken.Vault) {
            let fromType = from.getType()

            // These could be preconditions, but we probably save a tiny amount of gas by caching successive values
            let receiverCap = self.recipients[fromType.identifier]
                ?? panic("Cannot find Receiver capability of provided Vault type to deposit to")
            let receiverRef = receiverCap.borrow()
                ?? panic("Cannot borrow Receiver capability to deposit provided Vault to")

            let balance = from.balance

            receiverRef.deposit(from: <-from)

            emit TokensDispatched(type: fromType, amount: balance, via: self.owner?.address)
        }

        // setVaultRecipient
        //
        // Function that adds or changes the recipient for the given type.
        // Note two explicit design decisions here:
        // 1. We do not check that the Capability is in the same account as this resource.
        //    This allows tokens to be forwarded to Vaults in other accounts.
        // 2. We do not check that the Capability points to a Vault of the provided vaultType.
        //    This is to make sure that other resources can be sued, for example a token frowarder.
        // If we tried to prevent these use cases, they would be difficult or impossible to stop.
        // And doing so would remove flexibility from this resource.
        //
        pub fun setVaultRecipient(_ newRecipient: Capability<&{FungibleToken.Receiver}>, vaultType: Type) {
            pre {
                newRecipient.borrow() != nil: "Could not borrow Receiver reference from the Capability"
            }
            self.recipients[vaultType.identifier] = newRecipient
        }

        // removeVaultRecipient
        //
        // Function that removes the recipient of the forwarder for the given type.
        //
        pub fun removeVaultRecipient(vaultType: Type) {
            self.recipients.remove(key: vaultType.identifier)
        }

        // acceptsVault
        //
        // Function that checks whether the forwarder supports the provided Vault type.
        // This can always change after calling, and does not attempt to borrow the Vault,
        // so should at most be used as an immediate check in a transaction.
        //
        pub fun acceptsVault(type: Type): Bool {
          return self.recipients.containsKey(type.identifier)
        }

        //FIXME: if possible, remove acceptsVaultTypeIdentifiers and uncomment acceptsVaultTypes
        // acceptsVaultTypes
        //
        // Function that returns the Vault types that this switchboard accepts.
        // This is expensive until we can use Type as keys.
        //
        /*pub fun acceptsVaultTypes(): [Type] {
          let types: [Type] = []
          for typeString in self.recipients.keys {
              if let type = CompositeType(typeString) {
                types.append(type)
              }
          }
          return types
        }*/
        
        // acceptsVaultTypeIdentifiers
        //
        // Function that returns the Vault types string identifiers that this switchboard accepts.
        // This is a stop-gap until `CompositeType()` is supported.
        //
        pub fun acceptsVaultTypeIdentifiers(): [String] {
          return self.recipients.keys
        }

        pub init() {
            self.recipients = {}
        }
    }

    // createNewSwitchboard creates a new Forwarder reference with the provided recipient.
    //
    pub fun createNewSwitchboard(): @Switchboard {
        return <-create Switchboard()
    }

    init () {
        self.SwitchboardStoragePath = /storage/FungibleTokenSwitchboard
        self.SwitchboardPublicPath = /public/FungibleTokenSwitchboard
        self.SwitchboardPrivatePath = /private/FungibleTokenSwitchboard
    }
}