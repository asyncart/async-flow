from initialize_testing_environment import main
from transaction_handler import send_nft_auction_transaction
from script_handler import send_script, send_script_and_return_result
from event_handler import check_for_event
from utils import address, transfer_flow_token
import pytest

from test_unit_setup_async_user import setup_async_user
from test_unit_setup_marketplace_client import setup_marketplace_client
from test_unit_whitelist import whitelist
from test_unit_mint_master_token import mint_master_token
from test_unit_make_default_nft_auction import create_default_nft_auction
from test_unit_make_nft_auction import create_new_nft_auction
from test_unit_make_bid import make_bid

# expected args: nftTypeIdentifier: String, tokenId: UInt64

def withdraw_bid(args, signer, should_succeed, expected_result=None):
  txn_args = [["String", args[0]], ["UInt64", args[1]]]

  if should_succeed:
    assert send_nft_auction_transaction("withdrawBid", args=txn_args, signer=signer)
    event = f'A.{address("NFTAuction")[2:]}.NFTAuction.BidWithdrawn'
    assert check_for_event(event)
    result = send_script_and_return_result("getAuction", args=[["String", args[0]], ["UInt64", args[1]]])
    print(result)
    if expected_result != None:
      assert expected_result == result
    print("Successfuly Withdrew Bid")
  else:
    assert not send_nft_auction_transaction("withdrawBid", args=txn_args, signer=signer)
    print("Failed to Withdraw Bid as Expected")

@pytest.mark.core
def test_withdraw_bid():
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

  create_new_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "2.0", "5.0", "0.00000001", "5.0", [], []],
    "User1",
    True
  )

  transfer_flow_token("User2", "100.0", "emulator-account")

  # Cannot withdraw bid from auction that does not exist
  withdraw_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "2"],
    "User2",
    False
  )

  # Cannot withdraw bid that doesn't exist
  withdraw_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1"],
    "User2",
    False
  )

  make_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "1.0"],
    "User2",
    True
  )

  assert "99.00000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User2")]])

  # Non-bidder cannot withdraw bid
  withdraw_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1"],
    "User1",
    False
  )

  withdraw_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1"],
    "User2",
    True
  )

  assert "100.00000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User2")]])

  # Cannot withdraw bid that has already been withdrawn
  withdraw_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1"],
    "User2",
    False
  )

if __name__ == '__main__':
  test_withdraw_bid()