from initialize_testing_environment import main
from transaction_handler import send_transaction, send_nft_auction_transaction, send_async_artwork_transaction
from script_handler import send_script, send_script_and_return_result, send_async_artwork_script_and_return_result
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
from test_unit_settle_auction import settle_auction
import subprocess

# expected args: nftTypeIdentifier: String

def claim_nfts(args, signer, should_succeed, expected_result=None):
  txn_args = [["String", args[0]]]

  if should_succeed:
    assert send_nft_auction_transaction("claimNFTs", args=txn_args, signer=signer)
    print("Successfuly Claimed Owed NFTs")
  else:
    assert not send_nft_auction_transaction("claimNFTs", args=txn_args, signer=signer)
    print("Failed to Claim Owed NFTs as Expected")

@pytest.mark.core
def test_claim_nfts():
  # Deploy contracts
  main()

  setup_marketplace_client("User1")
  setup_marketplace_client("User2")

  setup_async_user("User1")
  setup_async_user("User2")

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
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "2.0", "5.0", "0.00000001", "5.0", ["AsyncArtAccount"], ["0.05"]],
    "User1",
    True
  )
  
  transfer_flow_token("User2", "100.0", "emulator-account")

  make_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "4.0"],
    "User2",
    True
  )

  # User2 unlinks their NFT receiver capability
  send_async_artwork_transaction("unlinkAsyncArtworkNFTCollectionPublicCapability", signer="User2")

  for i in range(120):
    send_transaction("simulateTimeDelay")

  settle_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1"],
    "User1",
    True
  )

  assert "3.80000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User1")]])
  assert "96.00000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User2")]])

  assert "[]" == send_async_artwork_script_and_return_result("getNFTs", args=[["Address", address("User1")]])
  
  # Confirm that user2 did not recieve the NFT back
  try:
    send_async_artwork_script_and_return_result("getNFTs", args=[["Address", address("User2")]])
  except subprocess.CalledProcessError:
    print("Unable to check find User2's owned NFTs as expected")

  # User2 relinks their NFT receiver capability before claiming their NFT back
  send_async_artwork_transaction("linkAsyncArtworkNFTCollectionPublicCapability", signer="User2")

  print("Relinked User2's NFT Receiver")

  # User cannot claim NFTs when not entitled to any
  claim_nfts(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT"],
    "User1",
    False
  )

  # Cannot claim NFTs of invalid type
  claim_nfts(
    ["A.01cf0e2f2f715450.AsyncArtwork.NF"],
    "User2",
    False
  )

  claim_nfts(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT"],
    "User2",
    True
  )

  # Confirm that user2 did get the NFT back, after claims
  user2_owned_nfts = send_async_artwork_script_and_return_result("getNFTs", args=[["Address", address("User2")]])
  assert "A.01cf0e2f2f715450.AsyncArtwork.NFT" in user2_owned_nfts and "id: 1" in user2_owned_nfts

if __name__ == '__main__':
  test_claim_nfts()