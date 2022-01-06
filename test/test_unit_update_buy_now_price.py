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
from test_unit_make_default_nft_auction import create_default_nft_auction
from test_unit_make_nft_auction import create_new_nft_auction
from test_unit_make_bid import make_bid
from test_unit_create_sale import create_new_sale

# expected args: nftTypeIdentifier, tokenId, newBuyNowPrice

def update_buy_now_price(args, signer, should_succeed, expected_result=None):
  txn_args = [["String", args[0]], ["UInt64", args[1]], ["UFix64", args[2]]]

  if should_succeed:
    assert send_transaction("updateBuyNowPrice", args=txn_args, signer=signer)
    event = f'A.{address("NFTAuction")[2:]}.NFTAuction.BuyNowPriceUpdated'
    assert check_for_event(event)
    res = send_script_and_return_result("getAuction", args=[["String", args[0]], ["UInt64", args[1]]])
    print(res)
    if expected_result != None:
      assert expected_result == res
    print("Successfuly Updated Buy Now Price")
  else:
    assert not send_transaction("updateBuyNowPrice", args=txn_args, signer=signer)
    print("Failed to Update Buy Now Price")

@pytest.mark.core
def test_update_buy_now_price():
  # Deploy contracts
  main()

  setup_marketplace_client("User1")
  setup_marketplace_client("User2")

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

  res = "A.120e725050340cab.NFTAuction.Auction(feeRecipients: [], feePercentages: [], nftHighestBid: nil, nftHighestBidder: nil, nftRecipient: nil, auctionBidPeriod: 86400.00000000, auctionEnd: nil, minPrice: 2.00000000, buyNowPrice: 5.00000000, biddingCurrency: \"A.0ae53cb6e3f42a79.FlowToken.Vault\", whitelistedBuyer: nil, nftSeller: 0x179b6b1cb6755e31, nftProviderCapability: Capability<&AnyResource{A.f8d6e0586b0a20c7.NonFungibleToken.Provider}>(address: 0x179b6b1cb6755e31, path: /private/AsyncArtworkCollection), bidIncreasePercentage: 0.10000000)"

  create_default_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "2.0", "10.0", [], []],
    "User1",
    True
  )

  # Cannot update buy now price on non-existent auction
  update_buy_now_price(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "2", "10.0"],
    "User2",
    False
  )

  # Non-nft seller cannot update buy now price
  update_buy_now_price(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "10.0"],
    "User2",
    False
  )

  # Cannot update buy now price such that min price is > 80% of the buy now price
  update_buy_now_price(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "2.1"],
    "User1",
    False
  )

  res = "A.120e725050340cab.NFTAuction.Auction(feeRecipients: [], feePercentages: [], nftHighestBid: nil, nftHighestBidder: nil, nftRecipient: nil, auctionBidPeriod: 86400.00000000, auctionEnd: nil, minPrice: 2.00000000, buyNowPrice: 10.00000000, biddingCurrency: \"A.0ae53cb6e3f42a79.FlowToken.Vault\", whitelistedBuyer: nil, nftSeller: 0x179b6b1cb6755e31, nftProviderCapability: Capability<&AnyResource{A.f8d6e0586b0a20c7.NonFungibleToken.Provider}>(address: 0x179b6b1cb6755e31, path: /private/AsyncArtworkCollection), bidIncreasePercentage: 0.10000000)"
  update_buy_now_price(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "10.0"],
    "User1",
    True,
    expected_result = res
  )

if __name__ == '__main__':
  test_update_buy_now_price()