from initialize_testing_environment import main
from transaction_handler import send_transaction
from script_handler import send_script, send_script_and_return_result
from event_handler import check_for_event
import json
import pytest

# Test specific setup functions
from test_create_async_collection import setup_accounts
from test_whitelist_token_for_creator import whitelist_token_for_creator

@pytest.mark.core

def mint_master():
  mint_args = [["UInt64", "1"], ["String", "<ex-uri>"], ["Array", [["Address", "0xf3fcd2c1a78f5eee"]]], ["Array", [["Address", "0xf3fcd2c1a78f5eee"]]]]
  assert send_transaction("mintMasterToken", args=mint_args, signer="User1")
  assert check_for_event("A.01cf0e2f2f715450.AsyncArtwork.Deposit")
  assert "{}" == send_script_and_return_result("getMasterMintReservation", args=[["Address", "0x179b6b1cb6755e31"]])
  print(send_script_and_return_result("getMetadata", args=[["UInt64", "1"]]))
  # Maybe add an asertion about the on-contract metadata
  print("Successfuly Minted Master NFT to Creator")

def test_mint_master():
  # Deploy contracts
  main()
  setup_accounts()
  whitelist_token_for_creator()
  mint_master()

if __name__ == '__main__':
    test_mint_master()