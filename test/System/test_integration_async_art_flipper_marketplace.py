from initialize_testing_environment import main
from transaction_handler import send_blueprints_transaction
from script_handler import send_async_artwork_script_and_return_result, send_script_and_return_result
from event_handler import check_for_event, check_for_n_event_occurences_over_x_blocks
from utils import address, transfer_flow_token
import pytest

from test_unit_setup_async_resources import setup_async_resources
from test_unit_acquire_minter import acquire_minter
from test_unit_begin_sale import begin_sale
from test_unit_make_nft_auction import create_new_nft_auction
from test_unit_make_bid import make_bid
from test_unit_take_highest_bid import take_highest_bid
from test_unit_create_sale import create_new_sale
from test_unit_whitelist import whitelist
from test_unit_mint_master_token import mint_master_token
from test_unit_mint_control_token import mint_control_token

@pytest.mark.core
def test_integration_async_art_flipper():
  # Deploy contracts
  main()
 
  setup_async_resources("User1")
  setup_async_resources("User2")
  setup_async_resources("User3")
  
  whitelist(
    ["User1", "1", "2", "0.01"],
    "AsyncArtAccount",
    True,
    "{1: 2}"
  )

  mint_master_token(
    ["1", "<uri>", ["User2", "User3"], ["User2"]],
    "User1",
    True
  )

  # assert on User1's ownership of the NFTs
  assert "id: 1" in send_async_artwork_script_and_return_result("getNFT", args=[["Address", address("User1")], ["UInt64", "1"]])

  transfer_flow_token("User2", "100.0", "emulator-account")
  transfer_flow_token("User1", "100.0", "emulator-account")
  transfer_flow_token("User3", "100.0", "emulator-account")

  create_new_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "2.0", "5.0", "50000.0", "0.1", ["AsyncArtAccount", "User2"], ["0.1", "0.02"]],
    "User1",
    True
  )

  make_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "3.0"],
    "User2",
    True
  )

  make_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "4.0"],
    "User3",
    True
  )

  take_highest_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1"],
    "User1", 
    True
  )

  # assert on User3's ownership of the NFTs
  assert "id: 1" in send_async_artwork_script_and_return_result("getNFT", args=[["Address", address("User3")], ["UInt64", "1"]])
  
  # assert on User1's balance
  assert "103.52000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User1")]])

  # assert on User2's balance
  assert "100.08000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User2")]])

  # assert on User3's balance
  assert "96.00000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User3")]])
  
  # assert on Async's balance
  assert "0.40000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("AsyncArtAccount")]])

  create_new_sale(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "10.0", address("User2"), [], []],
    "User3",
    True
  )
  
  make_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "10.0"],
    "User2",
    True
  )

  # assert on User2's ownership of the NFTs
  assert "id: 1" in send_async_artwork_script_and_return_result("getNFT", args=[["Address", address("User2")], ["UInt64", "1"]])
  
  # assert on User1's balance
  assert "103.52000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User1")]])

  # assert on User2's balance
  assert "90.28000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User2")]])

  # assert on User3's balance
  assert "104.80000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User3")]])
  
  # assert on Async's balance
  assert "1.40000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("AsyncArtAccount")]])

  mint_control_token(
    ["2", "<uri>", ["1", "1"], ["10", "20"], ["3", "18"], "5", ["User1", "User3"]],
    "User2",
    True,
    "{}"
  )

  mint_control_token(
    ["3", "<uri>", ["1", "1"], ["10", "20"], ["3", "18"], "5", ["User1", "User2"]],
    "User3",
    True,
    "{}"
  )

  create_new_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "2", "A.0ae53cb6e3f42a79.FlowToken.Vault", "2.0", "5.0", "50000.0", "0.1", ["AsyncArtAccount", "User2"], ["0.1", "0.02"]],
    "User2",
    True
  )

  make_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "2", "A.0ae53cb6e3f42a79.FlowToken.Vault", "3.0"],
    "User3",
    True
  )

  make_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "2", "A.0ae53cb6e3f42a79.FlowToken.Vault", "4.0"],
    "User1",
    True
  )

  take_highest_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "2"],
    "User2", 
    True
  )

  # assert on User1's ownership of the NFTs
  assert "id: 2" in send_async_artwork_script_and_return_result("getNFT", args=[["Address", address("User1")], ["UInt64", "2"]])
  
  # assert on User1's balance
  assert "99.52000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User1")]])

  # assert on User2's balance
  assert "93.88000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User2")]])

  # assert on User3's balance
  assert "104.80000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User3")]])
  
  # assert on Async's balance
  assert "1.80000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("AsyncArtAccount")]])

  create_new_sale(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "2", "A.0ae53cb6e3f42a79.FlowToken.Vault", "10.0", address("User3"), [], []],
    "User1",
    True
  )
  
  make_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "2", "A.0ae53cb6e3f42a79.FlowToken.Vault", "10.0"],
    "User3",
    True
  )

  # assert on User3's ownership of the NFTs
  assert "id: 2" in send_async_artwork_script_and_return_result("getNFT", args=[["Address", address("User3")], ["UInt64", "2"]])
  
  # assert on User1's balance
  assert "108.32000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User1")]])

  # assert on User2's balance
  assert "94.08000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User2")]])

  # assert on User3's balance
  assert "94.80000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User3")]])
  
  # assert on Async's balance
  assert "2.80000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("AsyncArtAccount")]])

  create_new_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "3", "A.0ae53cb6e3f42a79.FlowToken.Vault", "2.0", "5.0", "50000.0", "0.1", ["AsyncArtAccount", "User2"], ["0.1", "0.02"]],
    "User3",
    True
  )

  make_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "3", "A.0ae53cb6e3f42a79.FlowToken.Vault", "3.0"],
    "User1",
    True
  )

  make_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "3", "A.0ae53cb6e3f42a79.FlowToken.Vault", "4.0"],
    "User2",
    True
  )

  take_highest_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "3"],
    "User3", 
    True
  )

  # assert on User1's ownership of the NFTs
  assert "id: 3" in send_async_artwork_script_and_return_result("getNFT", args=[["Address", address("User2")], ["UInt64", "3"]])
  
  # assert on User1's balance
  assert "108.32000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User1")]])

  # assert on User2's balance
  assert "90.16000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User2")]])

  # assert on User3's balance
  assert "98.32000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User3")]])
  
  # assert on Async's balance
  assert "3.20000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("AsyncArtAccount")]])

  create_new_sale(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "3", "A.0ae53cb6e3f42a79.FlowToken.Vault", "10.0", address("User1"), [], []],
    "User2",
    True
  )
  
  make_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "3", "A.0ae53cb6e3f42a79.FlowToken.Vault", "10.0"],
    "User1",
    True
  )

  # assert on User3's ownership of the NFTs
  assert "id: 3" in send_async_artwork_script_and_return_result("getNFT", args=[["Address", address("User1")], ["UInt64", "3"]])
  
  # assert on User1's balance
  assert "98.32000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User1")]])

  # assert on User2's balance
  assert "99.16000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User2")]])

  # assert on User3's balance
  assert "98.32000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User3")]])
  
  # assert on Async's balance
  assert "4.20000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("AsyncArtAccount")]])

if __name__ == '__main__':
  test_integration_async_art_flipper()