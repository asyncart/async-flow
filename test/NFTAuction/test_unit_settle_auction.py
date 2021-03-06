from initialize_testing_environment import main
from transaction_handler import send_transaction, send_nft_auction_transaction
from script_handler import send_script, send_script_and_return_result, send_async_artwork_script_and_return_result, send_nft_auction_script_and_return_result
from event_handler import check_for_event
from utils import address, minimal_address, transfer_flow_token
import pytest

from test_unit_setup_async_resources import setup_async_resources
from test_unit_whitelist import whitelist
from test_unit_mint_master_token import mint_master_token
from test_unit_make_default_nft_auction import create_default_nft_auction
from test_unit_make_nft_auction import create_new_nft_auction
from test_unit_make_bid import make_bid

# expected args: nftTypeIdentifier: String, tokenId: UInt64

def settle_auction(args, signer, should_succeed, expected_result=None):
  txn_args = [["String", args[0]], ["UInt64", args[1]]]

  if should_succeed:
    assert send_nft_auction_transaction("settleAuction", args=txn_args, signer=signer)
    event = f'A.{address("NFTAuction")[2:]}.NFTAuction.AuctionSettled'
    assert check_for_event(event)
    result = send_nft_auction_script_and_return_result("getAuction", args=[["String", args[0]], ["UInt64", args[1]]])
    print(result)
    if expected_result != None:
      assert expected_result == result
    print("Successfuly Settled Auction")
  else:
    assert not send_nft_auction_transaction("settleAuction", args=txn_args, signer=signer)
    print("Failed to Settle Auction as Expected")

@pytest.mark.core
def test_settle_auction():
  # Deploy contracts
  main()

  setup_async_resources("User1")
  setup_async_resources("User2")
  setup_async_resources("User3")

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

  create_new_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "2.0", "5.0", "0.00000001", "0.1", ["AsyncArtAccount"], ["0.05"]],
    "User1",
    True
  )

  # Cannot settle auction before it has an end time
  settle_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1"],
    "User1",
    False
  )
  
  transfer_flow_token("User2", "100.0", "emulator-account")

  # Bid of less than minimum price should not set the end time for the auction
  make_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "1.0"],
    "User2",
    True
  )

  # Cannot settle auction before it has an end time
  settle_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1"],
    "User1",
    False
  )

  make_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "4.0"],
    "User2",
    True
  )

  for i in range(120):
    send_transaction("simulateTimeDelay")

  # Cannot settle auction that does not exist
  settle_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "2"],
    "User1",
    False
  )

  res = f'A.120e725050340cab.NFTAuction.Auction(feeRecipients: [{address("AsyncArtAccount")}], feePercentages: [0.05000000], nftHighestBid: nil, nftHighestBidder: nil, nftRecipient: nil, auctionBidPeriod: 86400.00000000, auctionEnd: nil, minPrice: nil, buyNowPrice: nil, biddingCurrency: \"A.0ae53cb6e3f42a79.FlowToken.Vault\", whitelistedBuyer: nil, nftSeller: nil, nftProviderCapability: nil, bidIncreasePercentage: 0.10000000)'
  settle_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1"],
    "User1",
    True,
    expected_result = res
  )

  # Cannot settle auction after just settled
  settle_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1"],
    "User1",
    False
  )

  assert "3.80000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User1")]])
  assert "96.00000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User2")]])

  assert "[]" == send_async_artwork_script_and_return_result("getNFTs", args=[["Address", address("User1")]])
  user2_owned_nfts = send_async_artwork_script_and_return_result("getNFTs", args=[["Address", address("User2")]])
  assert "A.01cf0e2f2f715450.AsyncArtwork.NFT" in user2_owned_nfts and "id: 1" in user2_owned_nfts

  create_new_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "2.0", "5.0", "0.00000001", "5.0", ["AsyncArtAccount"], ["0.05"]],
    "User2",
    True
  )

  make_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "3.0"],
    "User1",
    True
  )

  for i in range(120):
    send_transaction("simulateTimeDelay")

  # Can settle auction as non NFT seller, and as non bidder
  settle_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1"],
    "User3",
    True
  )

  assert "0.80000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User1")]])
  assert "98.85000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User2")]])

  user1_owned_nfts = send_async_artwork_script_and_return_result("getNFTs", args=[["Address", address("User1")]])
  assert "A.01cf0e2f2f715450.AsyncArtwork.NFT" in user1_owned_nfts and "id: 1" in user1_owned_nfts
  assert "[]" == send_async_artwork_script_and_return_result("getNFTs", args=[["Address", address("User2")]])


if __name__ == '__main__':
  test_settle_auction()