from initialize_testing_environment import main
from transaction_handler import send_transaction
from script_handler import send_script, send_script_and_return_result
from event_handler import check_for_event
import json
import pytest

# Test specific setup functions
from test_create_async_collection import setup_accounts

@pytest.mark.core

def whitelist_token_for_creator():
  whitelist_args = [["Address", "0x179b6b1cb6755e31"], ["UInt64", "0"], ["UInt64", "1"], ["UFix64", "5.0"], ["UFix64", "1.0"]]
  assert send_transaction("whitelist", args=whitelist_args, signer="AsyncArtAccount")
  assert "{0: 1}" == send_script_and_return_result("getMasterMintReservation", args=[["Address", "0x179b6b1cb6755e31"]])
  # Checks that the metadata entry here is non-empty
  assert send_script("getMetadata", args=[["UInt64", "0"]])
  assert check_for_event("A.01cf0e2f2f715450.AsyncArtwork.CreatorWhitelisted")
  print("Successfuly Whitelisted Token For Creator")

def test_whitelist():
  # Deploy contracts
  main()
  setup_accounts()
  whitelist_token_for_creator()

if __name__ == '__main__':
    test_whitelist()