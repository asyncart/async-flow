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
from test_unit_make_bid import make_bid

# expected args: nftTypeIdentifier: String, tokenId: UInt64, currency: String, tokenAmount: UFix64

def claim_payout(args, signer, should_succeed, expected_result=None):
  txn_args = [["String", args[0]]]

  if should_succeed:
    assert send_transaction("claimPayout", args=txn_args, signer=signer)
    print("Successfuly Claimed Payout")
  else:
    assert not send_transaction("claimPayout", args=txn_args, signer=signer)
    print("Failed to Claim Payment as Expected")

@pytest.mark.core
def test_make_bids():
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

  assert send_transaction("initializeAccount", signer="User2")
  assert send_transaction("mintFUSD", args=[["UFix64", "20.0"], ["Address", "0xf3fcd2c1a78f5eee"]])

  # Instantiate auction
  create_default_nft_art_auction(
    ["1", "A.f8d6e0586b0a20c7.FUSD.Vault", "2.0", "5.0", [], []],
    "User1",
    True
  )

  # Purchase NFT in FUSD, which the seller cannot yet receive
  make_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.f8d6e0586b0a20c7.FUSD.Vault", "6.0"],
    "User2",
    True
  )

  # Assert that User2 has payed for NFT and received it from User1
  assert "14.00000000" == send_script_and_return_result("getUsersFUSDBalance", args=[["Address", address("User2")]])
  assert "[A.01cf0e2f2f715450.AsyncArtwork.NFT(uuid: 57, id: 1)]" == send_script_and_return_result("getNFTs", args=[["Address", address("User2")]])
  assert "[]" == send_script_and_return_result("getNFTs", args=[["Address", address("User1")]])

  # Initialize User1 to receive standard non-default assets (i.e. FUSD)
  assert send_transaction("initializeAccount", signer="User1")

  # User1 should not have received their payout for the purchase of the NFT because
  assert "0.00000000" == send_script_and_return_result("getUsersFUSDBalance", args=[["Address", address("User1")]])

  # Cannot claim payment for unvalid currency
  claim_payout(
    ["A.f8d6e0586b0a20c7.FUSD.Vaul"],
    "User1",
    False
  )

  # Users cannot claim payment when not owed
  claim_payout(
    ["A.f8d6e0586b0a20c7.FUSD.Vault"],
    "User2",
    False
  )

  claim_payout(
    ["A.f8d6e0586b0a20c7.FUSD.Vault"],
    "User1",
    True
  )

  # User1 should now have their FUSD after claim
  assert "6.00000000" == send_script_and_return_result("getUsersFUSDBalance", args=[["Address", address("User1")]])

if __name__ == '__main__':
  test_make_bids()