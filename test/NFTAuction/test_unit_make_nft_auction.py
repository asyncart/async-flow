from initialize_testing_environment import main
from transaction_handler import send_nft_auction_transaction
from script_handler import send_nft_auction_script_and_return_result
from event_handler import check_for_event
from utils import address, minimal_address
import pytest

from test_unit_setup_async_resources import setup_async_resources
from test_unit_whitelist import whitelist
from test_unit_mint_master_token import mint_master_token 

# expected args: nftType, tokenId, currency, minPrice, buyNowPrice, auctionBidPeriod, bidIncreasePercentage, feeRecipients, feePercentages

def create_new_nft_auction(args, signer, should_succeed, expected_auction_result=None):
  fee_recipients = [["Address", address(user)] for user in args[7]]
  fee_percentages = [["UFix64", percentage] for percentage in args[8]]
  auction_args = [["String", args[0]], ["UInt64", args[1]], ["String", args[2]], ["UFix64", args[3]], ["UFix64", args[4]], ["UFix64", args[5]], ["UFix64", args[6]], ["Array", fee_recipients], ["Array", fee_percentages]]

  if should_succeed:
    assert send_nft_auction_transaction("createNewArtAuction", args=auction_args, signer=signer)
    event = f'A.{address("NFTAuction")[2:]}.NFTAuction.NftAuctionCreated'
    assert check_for_event(event)
    auction_result = send_nft_auction_script_and_return_result("getAuction", args=[["String", args[0]], ["UInt64", args[1]]])
    if expected_auction_result != None:
      assert expected_auction_result == auction_result
    print("Successfully Created NFT Auction")
  else:
    assert not send_nft_auction_transaction("createNewArtAuction", args=auction_args, signer=signer)
    print("Failed to Create NFT Auction as expected")

@pytest.mark.core
def test_make_new_nft_auction():
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
  create_new_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "2", "A.0ae53cb6e3f42a79.FlowToken.Vault", "2.0", "5.0", "50000.0", "5.0", [], []],
    "User1",
    False
  )

  # Attempt to make art auction with a minimum price that is too high
  create_new_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "4.1", "5.0", "50000.0", "5.0", [], []],
    "User1",
    False
  )

  # Attempt to make art auction with a minimum price that is too high
  create_new_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "4.1", "5.0", "50000.0", "5.0", [], []],
    "User1",
    False
  )

  # Attempt to make art auction with bid increase percentage below minium threshold
  create_new_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "2.1", "5.0", "50000.0", "0.01", [], []],
    "User1",
    False
  )

  # Attempt to make art auction with an invalid bidding currency
  create_new_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vau", "2.1", "5.0", "50000.0", "5.0", [], []],
    "User1",
    False
  )

  # Attempt to make art auction with an invalid sum of fee percentages (over 100)
  create_new_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vau", "2.1", "5.0", "50000.0", "5.0", ["User2"], ["105.0"]],
    "User1",
    False
  )

  # Attempt to make art auction with an invalid sum of fee percentages (over 100)
  create_new_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vau", "2.1", "5.0", "50000.0", "5.0", ["User2", "User3"], ["10.0", "95.0"]],
    "User1",
    False
  )

  # Attempt to make art auction with one feeRecipient but multiple percents
  create_new_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vau", "2.1", "5.0", "50000.0", "5.0", ["User2"], ["1.0", "95.0"]],
    "User1",
    False
  )

  # Attempt to make art auction with multiple feeRecipient but only one percentage
  create_new_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vau", "2.1", "5.0", "50000.0", "5.0", ["User2", "User3"], ["95.0"]],
    "User1",
    False
  )

  # Successfully create auction
  res = f'A.120e725050340cab.NFTAuction.Auction(feeRecipients: [{address("AsyncArtAccount")}, {address("User1")}], feePercentages: [0.10000000, 0.02000000], nftHighestBid: nil, nftHighestBidder: nil, nftRecipient: nil, auctionBidPeriod: 50000.00000000, auctionEnd: nil, minPrice: 2.00000000, buyNowPrice: 5.00000000, biddingCurrency: \"A.0ae53cb6e3f42a79.FlowToken.Vault\", whitelistedBuyer: nil, nftSeller: 0x179b6b1cb6755e31, nftProviderCapability: Capability<&AnyResource{{A.f8d6e0586b0a20c7.NonFungibleToken.Provider}}>(address: 0x179b6b1cb6755e31, path: /private/AsyncArtworkCollection), bidIncreasePercentage: 0.10000000)'
  create_new_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "2.0", "5.0", "50000.0", "0.1", ["AsyncArtAccount", "User1"], ["0.1", "0.02"]],
    "User1",
    True,
    expected_auction_result = res
  )

  # Attempt to re-create auction that was just started
  create_new_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "2.0", "5.0", "50000.0", "0.1", [], []],
    "User1",
    False
  )

if __name__ == '__main__':
  test_make_new_nft_auction()