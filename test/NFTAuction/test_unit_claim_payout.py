from initialize_testing_environment import main
from transaction_handler import send_transaction, send_nft_auction_transaction
from script_handler import send_script, send_script_and_return_result, send_async_artwork_script_and_return_result
from event_handler import check_for_event
from utils import address, transfer_flow_token
import pytest

from test_unit_setup_async_resources import setup_async_resources
from test_unit_whitelist import whitelist
from test_unit_mint_master_token import mint_master_token
from test_unit_make_default_nft_auction import create_default_nft_auction
from test_unit_make_bid import make_bid

# expected args: nftTypeIdentifier: String, tokenId: UInt64, currency: String, tokenAmount: UFix64

def claim_payout(args, signer, should_succeed, expected_result=None):
  txn_args = [["String", args[0]]]

  if should_succeed:
    assert send_nft_auction_transaction("claimPayout", args=txn_args, signer=signer)
    print("Successfuly Claimed Payout")
  else:
    assert not send_nft_auction_transaction("claimPayout", args=txn_args, signer=signer)
    print("Failed to Claim Payment as Expected")

@pytest.mark.core
def test_make_bids():
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

  assert send_transaction("setupFUSDVault", signer="User2")
  assert send_transaction("setupFUSDVault", signer="AsyncArtAccount")
  assert send_transaction("mintFUSD", args=[["UFix64", "20.0"], ["Address", address("User2")]])

  # Instantiate auction
  create_default_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.f8d6e0586b0a20c7.FUSD.Vault", "2.0", "5.0", ["AsyncArtAccount"], ["0.05"]],
    "User1",
    True
  )

  # User1 blocks themselves from immediately receiving payment
  assert send_transaction("unlinkFUSDReceiver", signer="User1")

  # Purchase NFT in FUSD, which the seller cannot yet receive
  make_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.f8d6e0586b0a20c7.FUSD.Vault", "6.0"],
    "User2",
    True
  )

  # Assert that User2 has payed for NFT and received it from User1
  assert "14.00000000" == send_script_and_return_result("getUsersFUSDBalance", args=[["Address", address("User2")]])

  # Assert that Async received appropriate fee
  assert "0.30000000" == send_script_and_return_result("getUsersFUSDBalance", args=[["Address", address("AsyncArtAccount")]])

  # Confirm user2 owns AsyncArtwork NFT 1
  user2_owned_nfts = send_async_artwork_script_and_return_result("getNFTs", args=[["Address", address("User2")]])
  assert "A.01cf0e2f2f715450.AsyncArtwork.NFT" in user2_owned_nfts and "id: 1" in user2_owned_nfts

  # Confirm that user1 does not own any AsyncArtwork NFTs
  assert "[]" == send_async_artwork_script_and_return_result("getNFTs", args=[["Address", address("User1")]])

  # Relink User1's FUSD receiver so that they can claim their payment
  assert send_transaction("relinkFUSDReceiver", signer="User1")

  # User1 should not have received their payout for the purchase of the NFT because they have not yet claimed their payment
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
  assert "5.70000000" == send_script_and_return_result("getUsersFUSDBalance", args=[["Address", address("User1")]])

if __name__ == '__main__':
  test_make_bids()