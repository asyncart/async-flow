// Used to manage FT and NFT paths + whitelisting

pub contract TokenRegistry {
    pub let claimerStoragePath: StoragePath

    // A mapping of currency type identifiers to expected paths
    access(self) let currencyPaths: {String: Paths}

    // managing claims on failed payouts

    // A mapping of currency type identifiers to intermediary claims vaults
    access(self) let claimsVaults: @{String: FungibleToken.Vault}

    // A mapping of currency type identifiers to {User Addresses -> Amounts of currency they are owed}
    access(self) let payoutClaims: {String: {Address: UFix64}}

    pub event CurrencyWhitelisted(currency: String)
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

    pub fun blueprintsPayout(
        recipient: Address,
        amount: @FungibleToken.Vault,
        currency: String,
        auth: Blueprints.Auth
    ) {
        self.payout(recipient: recipient, amount: <- amount, currency: currency)
    }

    pub fun asyncArtworkPayout(
        recipient: Address,
        amount: @FungibleToken.Vault,
        currency: String,
        auth: AsyncArtwork.Auth
    ) {
        self.payout(recipient: recipient, amount: <- amount, currency: currency)
    }

    access(self) fun _payClaims(
        recipient: Address, 
        amount: @FungibleToken.Vault,
        currency: String
    ) {
        var newClaim: UFix64 = 0.0
        if TokenRegistry.payoutClaims[currency]![recipient] == nil {
            newClaim = amount.balance
        } else {
            newClaim = TokenRegistry.payoutClaims[currency]![recipient]! + amount.balance
        }
        TokenRegistry.payoutClaims[currency]!.insert(key: recipient, newClaim)

        let claimsVault <- TokenRegistry.claimsVaults.remove(key: currency)!
        claimsVault.deposit(from: <- amount)

        // This should always destroy an empty resource
        destroy <- TokenRegistry.claimsVaults.insert(key: currency, <- claimsVault)
    }

    pub fun getCurrencyPaths(): {String: Paths} {
        return self.currencyPaths
    }

    pub fun isCurrencySupported(currency: String): Bool {
        return self.currencyPaths.containsKey(currency)
    }

    pub fun isValidCurrencyFormat(_currency: String): Bool {
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

    pub resource Platform {
        // whitelist currency
        pub fun whitelistCurrency(
            currency: String,
            currencyPublicPath: PublicPath,
            currencyPrivatePath: PrivatePath,
            currencyStoragePath: StoragePath,
            vault: @FungibleToken.Vault
        ) {
            pre {
                TokenRegistry.isValidCurrencyFormat(_currency: currency) : "Currency identifier is invalid"
                !TokenRegistry.isCurrencySupported(currency: currency): "Currency is already whitelisted"
            }

            post {
                TokenRegistry.isCurrencySupported(currency: currency): "Currency not whitelisted successfully"
            }

            TokenRegistry.currencyPaths[currency] = Paths(
                currencyPublicPath,
                currencyPrivatePath,
                currencyStoragePath
            )

            TokenRegistry.payoutClaims.insert(key: currency, {})
            destroy <- TokenRegistry.claimsVaults.insert(key: currency, <- vault)

            emit CurrencyWhitelisted(currency: currency)
        }

        // unwhitelist currency
        pub fun unwhitelistCurrency(
            currency: String
        ) {
            pre {
                TokenRegistry.isCurrencySupported(currency: currency): "Currency is not whitelisted"
            }

            post {
                !TokenRegistry.isCurrencySupported(currency: currency): "Currency unwhitelist failed"
            }

            TokenRegistry.currencyPaths.remove(key: currency)
            TokenRegistry.payoutClaims.remove(key: currency)

            // Warning this could permanently remove funds from claims -- but claims is already quite accomodating so we won't block
            // admin if the claims vault is non-empty
            destroy <- TokenRegistry.claimsVaults.remove(key: currency)

            emit CurrencyUnwhitelisted(currency: currency)
        }
    }

    pub resource Claimer {
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

    pub fun createClaimer(): @Claimer {
        return <- create Claimer
    }

    init(flowTokenCurrencyType: String, fusdCurrencyType: String) {
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

        self.claimerStoragePath = /storage/asyncTokenRegistryClaimer

        // Create a Platform resource and save it to storage
        let platform <- create Platform()
        self.account.save(<-platform, to: self.platformStoragePath)
    }
}