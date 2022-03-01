from initialize_testing_environment import main
from transaction_handler import send_transaction, send_nft_auction_transaction
from script_handler import send_script, send_script_and_return_result, send_async_artwork_script_and_return_result, send_nft_auction_script_and_return_result
from event_handler import check_for_event
from utils import address, transfer_flow_token
import pytest

from test_unit_setup_async_user import setup_async_user
from test_unit_setup_marketplace_client import setup_marketplace_client
from test_unit_whitelist import whitelist
from test_unit_mint_master_token import mint_master_token
from test_unit_make_default_nft_auction import create_default_nft_auction

# expected args: nftTypeIdentifier: String, tokenId: UInt64, currency: String, tokenAmount: UFix64, nftRecipient: Address

def make_custom_bid(args, signer, should_succeed, expected_result=None):
  txn_args = [["String", args[0]], ["UInt64", args[1]], ["String", args[2]], ["UFix64", args[3]], ["Address", args[4]]]

  if should_succeed:
    assert send_nft_auction_transaction("makeCustomBid", args=txn_args, signer=signer)
    event = f'A.{address("NFTAuction")[2:]}.NFTAuction.BidMade'
    assert check_for_event(event)
    result = send_nft_auction_script_and_return_result("getAuction", args=[["String", args[0]], ["UInt64", args[1]]])
    print(result)
    if expected_result != None:
      assert expected_result == result
    print("Successfuly Placed Custom Bid")
  else:
    assert not send_nft_auction_transaction("makeCustomBid", args=txn_args, signer=signer)
    print("Failed to Make Custom Bid as expected")

@pytest.mark.core
def test_make_custom_bids():
  # Deploy contracts
  main()

  setup_marketplace_client("User1")
  setup_marketplace_client("User2")

  setup_async_user("User1")
  setup_async_user("User2")

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

  transfer_flow_token("User2", "100.0", "emulator-account")

  # Cannot bid with more FTs than currently owned
  make_custom_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "102.0", "0x179b6b1cb6755e31"],
    "User2",
    False
  )

  # Cannot bid in non-supported currency
  make_custom_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vau", "102.0", "0x179b6b1cb6755e31"],
    "User2",
    False
  )

  assert send_transaction("initializeAccount", signer="User2")
  assert send_transaction("mintFUSD", args=[["UFix64", "20.0"], ["Address", "0xf3fcd2c1a78f5eee"]])

  # Cannot early bid in non-FlowToken currency
  make_custom_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.f8d6e0586b0a20c7.FUSD.Vault", "15.0", "0x179b6b1cb6755e31"],
    "User2",
    False
  )

  # early bid should succeed
  res = "A.120e725050340cab.NFTAuction.Auction(feeRecipients: [], feePercentages: [], nftHighestBid: 3.00000000, nftHighestBidder: 0xf3fcd2c1a78f5eee, nftRecipient: 0x179b6b1cb6755e31, auctionBidPeriod: 86400.00000000, auctionEnd: nil, minPrice: nil, buyNowPrice: nil, biddingCurrency: \"A.0ae53cb6e3f42a79.FlowToken.Vault\", whitelistedBuyer: nil, nftSeller: nil, nftProviderCapability: nil, bidIncreasePercentage: 0.10000000)"
  make_custom_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "3.0", "0x179b6b1cb6755e31"],
    "User2",
    True,
    expected_result = res
  )

  assert "97.00000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User2")]])

  # Check that NFT is still owned by User1 since they haven't started an auction yet
  user1_owned_nfts = send_async_artwork_script_and_return_result("getNFTs", args=[["Address", address("User1")]])
  assert "A.01cf0e2f2f715450.AsyncArtwork.NFT" in user1_owned_nfts and "id: 1" in user1_owned_nfts

  create_default_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "2.0", "5.0", [], []],
    "User1",
    True
  )

  # it is difficult to assert on the auction metadata after subsequent bidding due to time error on auctionEndTime
  make_custom_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "4.0", "0x179b6b1cb6755e31"],
    "User2",
    True
  )

  assert "96.00000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User2")]])

if __name__ == '__main__':
  test_make_custom_bids()