from initialize_testing_environment import main
from transaction_handler import send_nft_auction_transaction
from script_handler import send_script, send_script_and_return_result, send_async_artwork_script_and_return_result, send_nft_auction_script_and_return_result
from event_handler import check_for_event
from utils import address, transfer_flow_token
import pytest

from test_unit_setup_async_user import setup_async_user
from test_unit_setup_marketplace_client import setup_marketplace_client
from test_unit_whitelist import whitelist
from test_unit_mint_master_token import mint_master_token
from test_unit_mint_control_token import mint_control_token
from test_unit_make_default_nft_auction import create_default_nft_auction
from test_unit_make_nft_auction import create_new_nft_auction
from test_unit_make_bid import make_bid
from test_unit_take_highest_bid import take_highest_bid

@pytest.mark.core
def test_system_art_master_royalties():
  # Deploy contracts
  main()

  setup_marketplace_client("User1")
  setup_marketplace_client("User2")
  setup_marketplace_client("User3")
  setup_marketplace_client("User4")

  setup_async_user("User1")
  setup_async_user("User2")
  setup_async_user("User3")
  setup_async_user("User4")

  # Test royalties with default percentages on master token nfts
  whitelist(
    ["User1", "1", "1", None],
    "AsyncArtAccount",
    True,
    "{1: 1}"
  )

  # second array is royalty recipients
  mint_master_token(
    ["1", "<uri>", ["User3"], ["User2", "User3"]],
    "User1",
    True,
    "{}"
  )

  # create an auction for the master token
  create_new_nft_auction(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "2.0", "5.0", "0.00000001", "5.0", ["AsyncArtAccount"], ["0.1"]],
    "User1",
    True
  )
  
  # sell the NFT to user4 via auction
  transfer_flow_token("User4", "100.0", "emulator-account")
  make_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "4.0"],
    "User4",
    True
  )
  take_highest_bid(
    ["A.01cf0e2f2f715450.AsyncArtwork.NFT", "1"],
    "User1",
    True
  )

  # all but 10% of the bid should go to the artist -> the rest goes to the platform
  # currently, the creatorTokenArtists don't receive any roylaties on the first sale
  # @TODO: validate that this is correct
  assert "3.60000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User1")]])

  # User2 and User3 don't get royalties here because we don't give any royalties after the first sale
  assert "0.00000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User2")]])
  assert "0.00000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User3")]])

  # User4 paid the fee
  assert "96.00000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User4")]])

  #Platform received the appropriate payout -> 10% is the the default primary fee percentage
  assert "0.40000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("AsyncArtAccount")]])

  # Assert on ownership
  assert "[]" == send_async_artwork_script_and_return_result("getNFTs", args=[["Address", address("User1")]])
  user4_owned_nfts = send_async_artwork_script_and_return_result("getNFTs", args=[["Address", address("User4")]])
  assert "A.01cf0e2f2f715450.AsyncArtwork.NFT" in user4_owned_nfts and "id: 1" in user4_owned_nfts

if __name__ == '__main__':
  test_system_art_master_royalties()