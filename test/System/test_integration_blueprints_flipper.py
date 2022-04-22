from initialize_testing_environment import main
from transaction_handler import send_blueprints_transaction
from script_handler import send_blueprints_script_and_return_result, send_script_and_return_result
from event_handler import check_for_event, check_for_n_event_occurences_over_x_blocks
from utils import address, transfer_flow_token
import pytest

from test_unit_setup_blueprints_user import setup_blueprints_user
from test_unit_acquire_minter import acquire_minter
from test_unit_prepare_blueprint import prepare_blueprint
from test_unit_begin_sale import begin_sale
from test_unit_purchase_blueprints import purchase_blueprints
from test_unit_make_nft_auction import create_new_nft_auction
from test_unit_setup_marketplace_client import setup_marketplace_client
from test_unit_make_bid import make_bid
from test_unit_take_highest_bid import take_highest_bid
from test_unit_create_sale import create_new_sale

@pytest.mark.core
def test_integration_blueprints_flipper():
  # Deploy contracts
  main()
 
  setup_marketplace_client("User1")
  setup_marketplace_client("User2")
  setup_marketplace_client("User3")
  
  # Confirm that designated minter can prepare blueprint
  prepare_blueprint(
    ["User1", "5", "10.0", "A.0ae53cb6e3f42a79.FlowToken.Vault", "metadata", "https://token-uri.com", ["User2"], "1", "2", "2"],
    "AsyncArtAccount",
    True
  )

  # User2 acquires tokens to purchase blueprints
  transfer_flow_token("User2", "100.0", "emulator-account")
  transfer_flow_token("User1", "100.0", "emulator-account")
  transfer_flow_token("User3", "100.0", "emulator-account")
  setup_blueprints_user("User2")
  setup_blueprints_user("User1")
  setup_blueprints_user("User3")

  purchase_blueprints(
    ["0", "1", "User2"],
    "User2",
    True
  )

  # assert on User2's ownership of the NFTs
  assert "id: 0" in send_blueprints_script_and_return_result("getNFT", args=[["Address", address("User2")], ["UInt64", "0"]])
  
  # assert on User2's balance
  assert "90.00000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User2")]])
  
  # assert on Async's balance
  assert "2.00000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("AsyncArtAccount")]])

  # assert on User1's balance
  assert "108.00000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User1")]])

  # assert on User3's balance
  assert "100.00000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User3")]])

  create_new_nft_auction(
    ["A.01cf0e2f2f715450.Blueprints.NFT", "0", "A.0ae53cb6e3f42a79.FlowToken.Vault", "2.0", "5.0", "50000.0", "0.1", ["AsyncArtAccount", "User1"], ["0.1", "0.02"]],
    "User2",
    True
  )

  make_bid(
    ["A.01cf0e2f2f715450.Blueprints.NFT", "0", "A.0ae53cb6e3f42a79.FlowToken.Vault", "3.0"],
    "User1",
    True
  )

  take_highest_bid(
    ["A.01cf0e2f2f715450.Blueprints.NFT", "0"],
    "User2", 
    True
  )

  # assert on User1's ownership of the NFTs
  assert "id: 0" in send_blueprints_script_and_return_result("getNFT", args=[["Address", address("User1")], ["UInt64", "0"]])
  
  # assert on User2's balance
  assert "92.64000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User2")]])
  
  # assert on Async's balance
  assert "2.30000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("AsyncArtAccount")]])

  # assert on User1's balance
  assert "105.06000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User1")]])

  create_new_sale(
    ["A.01cf0e2f2f715450.Blueprints.NFT", "0", "A.0ae53cb6e3f42a79.FlowToken.Vault", "10.0", address("User3"), [], []],
    "User1",
    True
  )
  
  make_bid(
    ["A.01cf0e2f2f715450.Blueprints.NFT", "0", "A.0ae53cb6e3f42a79.FlowToken.Vault", "15.0"],
    "User3",
    True
  )

  # assert on User3's ownership of the NFTs
  assert "id: 0" in send_blueprints_script_and_return_result("getNFT", args=[["Address", address("User3")], ["UInt64", "0"]])
  
  # assert on Async's balance
  assert "3.80000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("AsyncArtAccount")]])

  # assert on User1's balance
  assert "118.56000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User1")]])

if __name__ == '__main__':
  test_integration_blueprints_flipper()