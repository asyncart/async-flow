from initialize_testing_environment import main
from transaction_handler import send_transaction
from script_handler import send_script, send_script_and_return_result
from event_handler import check_for_event
from utils import address
import pytest

from test_unit_setup_async_user import setup_async_user
from test_unit_setup_marketplace_client import setup_marketplace_client
from test_unit_whitelist import whitelist
from test_unit_mint_master_token import mint_master_token
from test_unit_make_default_nft_art_auction import create_default_nft_art_auction
from test_unit_make_nft_art_auction import create_new_nft_art_auction
from test_unit_make_bid import make_bid
from test_unit_create_art_sale import create_new_art_sale

# expected args: nftTypeIdentifier, tokenId, newWhitelistedBuyer

def update_whitelisted_buyer(args, signer, should_succeed, expected_result=None):
  txn_args = [["String", args[0]], ["UInt64", args[1]], ["Address", args[2]]]

  if should_succeed:
    assert send_transaction("updateWhitelistedBuyer", args=txn_args, signer=signer)
    event = f'A.{address("NFTAuction")[2:]}.NFTAuction.WhitelistedBuyerUpdated'
    assert check_for_event(event)
    res = send_script_and_return_result("getAuction", args=[["String", args[0]], ["UInt64", args[1]]])
    print(res)
    if expected_result != None:
      assert expected_result == res
    print("Successfuly Updated Whitelisted Buyer for Sale")
  else:
    assert not send_transaction("updateWhitelistedBuyer", args=txn_args, signer=signer)
    print("Failed to Update Whitelisted Buer For Sale as Expected")

@pytest.mark.core
def test_update_whitelisted_buyer():
  # Deploy contracts
  main()

  setup_marketplace_client("User1")

  setup_async_user("User1")

  whitelist(
    ["User1", "1", "0", "5.0", "1.0"],
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

  # We might want to refactor the contract to make "auctionBidPeriod" and "bidIncreasePercentage" optional, nil seems more appropriate here than the default values
  res = "A.120e725050340cab.NFTAuction.Auction(feeRecipients: [], feePercentages: [], nftHighestBid: nil, nftHighestBidder: nil, nftRecipient: nil, auctionBidPeriod: 86400.00000000, auctionEnd: nil, minPrice: nil, buyNowPrice: 10.00000000, biddingCurrency: \"A.0ae53cb6e3f42a79.FlowToken.Vault\", whitelistedBuyer: 0xe03daebed8ca0615, nftSeller: 0x179b6b1cb6755e31, nftProviderCapability: Capability<&AnyResource{A.f8d6e0586b0a20c7.NonFungibleToken.Provider}>(address: 0x179b6b1cb6755e31, path: /private/AsyncArtworkCollection), bidIncreasePercentage: 0.10000000)"

  # Good to note that we currenctly support whitelisting a buyer who is not an async user, I think that's what we want
  # but we might want to bubble up a warning to the frontend if someone tries to do this
  create_new_art_sale(
    ["1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "10.0", "0xe03daebed8ca0615", [], []],
    "User1",
    True,
    expected_auction_result = res
  )

  # Cannot update whitelisted buyer on non-existent sale
  update_whitelisted_buyer(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "2", "0xf3fcd2c1a78f5eee"],
    "User1",
    False
  )

  # Non-nft seller cannot update whitelisted buyer on sale
  update_whitelisted_buyer(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "0xf3fcd2c1a78f5eee"],
    "User2",
    False
  )

  res = "A.120e725050340cab.NFTAuction.Auction(feeRecipients: [], feePercentages: [], nftHighestBid: nil, nftHighestBidder: nil, nftRecipient: nil, auctionBidPeriod: 86400.00000000, auctionEnd: nil, minPrice: nil, buyNowPrice: 10.00000000, biddingCurrency: \"A.0ae53cb6e3f42a79.FlowToken.Vault\", whitelistedBuyer: 0x179b6b1cb6755e31, nftSeller: 0x179b6b1cb6755e31, nftProviderCapability: Capability<&AnyResource{A.f8d6e0586b0a20c7.NonFungibleToken.Provider}>(address: 0x179b6b1cb6755e31, path: /private/AsyncArtworkCollection), bidIncreasePercentage: 0.10000000)"
  # NFT seller can set whitelisted buyer to themselves (we should maybe prevent this, because they are not allowed to purchase from themselves)
  update_whitelisted_buyer(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "0x179b6b1cb6755e31"],
    "User1",
    True,
    expected_result = res
  )

if __name__ == '__main__':
  test_update_whitelisted_buyer()