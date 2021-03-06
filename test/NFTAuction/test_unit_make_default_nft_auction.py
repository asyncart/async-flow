from initialize_testing_environment import main
from transaction_handler import send_nft_auction_transaction
from script_handler import send_nft_auction_script_and_return_result
from event_handler import check_for_event
from utils import address
import pytest

from test_unit_setup_async_resources import setup_async_resources
from test_unit_whitelist import whitelist
from test_unit_mint_master_token import mint_master_token 

# expected args: tokenId, currency, minPrice, buyNowPrice, feeRecipients, feePercentages

def create_default_nft_auction(args, signer, should_succeed, expected_auction_result=None):
  fee_recipients = [["Address", address(user)] for user in args[5]]
  fee_percentages = [["UFix64", percentage] for percentage in args[6]]
  auction_args = [["String", args[0]], ["UInt64", args[1]], ["String", args[2]], ["UFix64", args[3]], ["UFix64", args[4]], ["Array", fee_recipients], ["Array", fee_percentages]]

  if should_succeed:
    assert send_nft_auction_transaction("createDefaultNFTAuction", args=auction_args, signer=signer)
    event = f'A.{address("NFTAuction")[2:]}.NFTAuction.NftAuctionCreated'
    assert check_for_event(event)
    auction_result = send_nft_auction_script_and_return_result("getAuction", args=[["String", args[0]], ["UInt64", args[1]]])
    print(auction_result)
    if expected_auction_result != None:
      assert expected_auction_result == auction_result
    print("Successfuly Created Default NFT Auction")
  else:
    assert not send_nft_auction_transaction("createDefaultNFTAuction", args=auction_args, signer=signer)
    print("Failed to Create Default NFT Auction as expected")

@pytest.mark.core
def test_make_default_nft_auction():
  # Deploy contracts
  main()

  setup_async_resources("User1")

  whitelist(
    ["User1", "1", "0", "0.01"],
    "AsyncArtAccount",
    True,
    "{1: 0}"
  )

  mint_master_token(
    ["1", "<uri>", [], []],
    "User1",
    True,
    "{}"
  )

  # Attempt to make art auction for AsyncNFT id not owned by creator
  create_default_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "2", "A.0ae53cb6e3f42a79.FlowToken.Vault", "2.0", "5.0", [], []],
    "User1",
    False
  )

  # Attempt to make art auction with a minimum price that is too high
  create_default_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "4.1", "5.0", [], []],
    "User1",
    False
  )

  # Attempt to make art auction with a minimum price that is too high
  create_default_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "4.1", "5.0", [], []],
    "User1",
    False
  )

  # Attempt to make art auction with an invalid bidding currency
  create_default_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vau", "2.1", "5.0", [], []],
    "User1",
    False
  )

  # Attempt to make art auction with an invalid sum of fee percentages (over 100)
  create_default_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vau", "2.1", "5.0", ["User2"], ["105.0"]],
    "User1",
    False
  )

  # Attempt to make art auction with an invalid sum of fee percentages (over 100)
  create_default_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vau", "2.1", "5.0", ["User2", "User3"], ["10.0", "95.0"]],
    "User1",
    False
  )

  # Attempt to make art auction with one feeRecipient but multiple percents
  create_default_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vau", "2.1", "5.0", ["User2"], ["1.0", "95.0"]],
    "User1",
    False
  )

  # Attempt to make art auction with multiple feeRecipient but only one percentage
  create_default_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vau", "2.1", "5.0", ["User2", "User3"], ["95.0"]],
    "User1",
    False
  )

  res = "A.120e725050340cab.NFTAuction.Auction(feeRecipients: [], feePercentages: [], nftHighestBid: nil, nftHighestBidder: nil, nftRecipient: nil, auctionBidPeriod: 86400.00000000, auctionEnd: nil, minPrice: 2.00000000, buyNowPrice: 5.00000000, biddingCurrency: \"A.0ae53cb6e3f42a79.FlowToken.Vault\", whitelistedBuyer: nil, nftSeller: 0x179b6b1cb6755e31, nftProviderCapability: Capability<&AnyResource{A.f8d6e0586b0a20c7.NonFungibleToken.Provider}>(address: 0x179b6b1cb6755e31, path: /private/AsyncArtworkCollection), bidIncreasePercentage: 0.10000000)"
  create_default_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "2.0", "5.0", [], []],
    "User1",
    True,
    expected_auction_result = res
  )

  # Attempt to re-create NFT Auction that was just created
  create_default_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "2.0", "5.0", [], []],
    "User1",
    False
  )

if __name__ == '__main__':
  test_make_default_nft_auction()