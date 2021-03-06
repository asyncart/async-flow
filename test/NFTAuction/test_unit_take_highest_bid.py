from initialize_testing_environment import main
from transaction_handler import send_nft_auction_transaction
from script_handler import send_script, send_script_and_return_result, send_async_artwork_script_and_return_result, send_nft_auction_script_and_return_result
from event_handler import check_for_event
from utils import address, transfer_flow_token
import pytest

from test_unit_setup_async_resources import setup_async_resources
from test_unit_whitelist import whitelist
from test_unit_mint_master_token import mint_master_token
from test_unit_make_default_nft_auction import create_default_nft_auction
from test_unit_make_nft_auction import create_new_nft_auction
from test_unit_make_bid import make_bid

# expected args: nftTypeIdentifier: String, tokenId: UInt64

def take_highest_bid(args, signer, should_succeed, expected_result=None):
  txn_args = [["String", args[0]], ["UInt64", args[1]]]

  if should_succeed:
    assert send_nft_auction_transaction("takeHighestBid", args=txn_args, signer=signer)
    event = f'A.{address("NFTAuction")[2:]}.NFTAuction.HighestBidTaken'
    assert check_for_event(event)
    result = send_nft_auction_script_and_return_result("getAuction", args=[["String", args[0]], ["UInt64", args[1]]])
    print(result)
    if expected_result != None:
      assert expected_result == result
    print("Successfuly Accepted Highest Bid")
  else:
    assert not send_nft_auction_transaction("takeHighestBid", args=txn_args, signer=signer)
    print("Failed to Accept Highest Bid as Expected")

@pytest.mark.core
def test_take_highest_bid():
  # Deploy contracts
  main()

  setup_async_resources("User1")
  setup_async_resources("User2")

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

  # Cannot take highest bid on non-existent auction
  take_highest_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1"],
    "User1",
    False
  )

  create_new_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "2.0", "5.0", "0.00000001", "5.0", ["AsyncArtAccount"], ["0.05"]],
    "User1",
    True
  )

  # Cannot take highest bid before one exists
  take_highest_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1"],
    "User1",
    False
  )
  
  transfer_flow_token("User2", "100.0", "emulator-account")

  make_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "4.0"],
    "User2",
    True
  )

  # Non nft seller cannot take highest bid
  take_highest_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1"],
    "User2",
    False
  )

  res = "A.120e725050340cab.NFTAuction.Auction(feeRecipients: [], feePercentages: [], nftHighestBid: nil, nftHighestBidder: nil, nftRecipient: nil, auctionBidPeriod: 86400.00000000, auctionEnd: nil, minPrice: nil, buyNowPrice: nil, biddingCurrency: \"A.0ae53cb6e3f42a79.FlowToken.Vault\", whitelistedBuyer: nil, nftSeller: nil, nftProviderCapability: nil, bidIncreasePercentage: 0.10000000)"
  take_highest_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1"],
    "User1",
    True
  )

  assert "3.80000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User1")]])
  assert "0.20000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("AsyncArtAccount")]])
  assert "96.00000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User2")]])

  assert "[]" == send_async_artwork_script_and_return_result("getNFTs", args=[["Address", address("User1")]])
  user2_owned_nfts = send_async_artwork_script_and_return_result("getNFTs", args=[["Address", address("User2")]])
  assert "A.01cf0e2f2f715450.AsyncArtwork.NFT" in user2_owned_nfts and "id: 1" in user2_owned_nfts

  # Cannot take highest bid twice
  take_highest_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1"],
    "User1",
    False
  )

if __name__ == '__main__':
  test_take_highest_bid()