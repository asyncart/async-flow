// Use this contract as a placeholder until a royalty standard contract is deployed to mainnet

pub contract Royalties {
    /// A struct interface for Royalty agreed upon by @dete, @rheaplex, @bjartek 
	pub struct interface Royalty {

		/// if nil cannot pay this type
		/// if not nill withdraw that from main vault and put it into distributeRoyalty 
		pub fun calculateRoyalty(type: Type, amount: UFix64) : UFix64?

		/// call this with a vault containing the amount given in calculate royalty and it will be distributed accordingly
		pub fun distributeRoyalty(vault: @FungibleToken.Vault) 

		/// generate a string that represents all the royalties this NFT has for display purposes
		pub fun displayRoyalty() : String?  

	}
}