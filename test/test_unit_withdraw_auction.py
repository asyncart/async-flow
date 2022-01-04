from initialize_testing_environment import main
from transaction_handler import send_transaction
from script_handler import send_script, send_script_and_return_result
from event_handler import check_for_event
from utils import address, transfer_flow_token
import pytest

from test_unit_setup_async_user import setup_async_user
from test_unit_setup_marketplace_client import setup_marketplace_client
from test_unit_whitelist import whitelist
from test_unit_mint_master_token import mint_master_token
from test_unit_make_default_nft_art_auction import create_default_nft_art_auction
from test_unit_make_nft_art_auction import create_new_nft_art_auction
from test_unit_make_bid import make_bid

# expected args: nftTypeIdentifier: String, tokenId: UInt64

def withdraw_auction(args, signer, should_succeed, expected_result=None):
  txn_args = [["String", args[0]], ["UInt64", args[1]]]

  if should_succeed:
    assert send_transaction("withdrawAuction", args=txn_args, signer=signer)
    event = f'A.{address("NFTAuction")[2:]}.NFTAuction.AuctionWithdrawn'
    assert check_for_event(event)
    result = send_script_and_return_result("getAuction", args=[["String", args[0]], ["UInt64", args[1]]])
    print(result)
    if expected_result != None:
      assert expected_result == result
    print("Auction Successfully Withdrawn")
  else:
    assert not send_transaction("withdrawAuction", args=txn_args, signer=signer)
    print("Failed to Withdraw Auction as Expected")

@pytest.mark.core
def test_withdraw_auction():
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

  create_new_nft_art_auction(
    ["1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "2.0", "5.0", "0.00000001", "5.0", [], []],
    "User1",
    True
  )

  res = "A.120e725050340cab.NFTAuction.Auction(feeRecipients: [], feePercentages: [], nftHighestBid: nil, nftHighestBidder: nil, nftRecipient: nil, auctionBidPeriod: 86400.00000000, auctionEnd: nil, minPrice: nil, buyNowPrice: nil, biddingCurrency: \"A.0ae53cb6e3f42a79.FlowToken.Vault\", whitelistedBuyer: nil, nftSeller: nil, nftProviderCapability: nil, bidIncreasePercentage: 0.10000000)"

  withdraw_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1"],
    "User1",
    True,
    expected_result = res
  )

if __name__ == '__main__':
  test_withdraw_auction()