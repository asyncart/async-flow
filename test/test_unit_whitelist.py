from initialize_testing_environment import main
from transaction_handler import send_transaction
from script_handler import send_script, send_script_and_return_result
from event_handler import check_for_event
from utils import address
import json
import pytest

# Test specific setup functions
from test_unit_setup_async_user import setup_async_user

@pytest.mark.core

# expected args: [creator, masterTokenId, layerCount, platformFirstSalePercentage, platformSecondSalePercentage]
def whitelist(args, signer, should_succeed, expected_master_mint_res):
  creator_address = address(args[0])
  args = [["Address", creator_address], ["UInt64", args[1]], ["UInt64", args[2]], ["UFix64", args[3]], ["UFix64", args[4]]]
  if should_succeed:
    assert send_transaction("whitelist", args=args, signer=signer)
    assert expected_master_mint_res == send_script_and_return_result("getMasterMintReservation", args=[["Address", creator_address]])
    # Checks that the metadata entry here is non-empty
    assert send_script("getMetadata", args=[args[1]])
    assert check_for_event(f'A.{address("AsyncArtwork")[2:]}.AsyncArtwork.CreatorWhitelisted')
    print("Successfuly Whitelisted Token For Creator")
  else:
    assert not send_transaction("whitelist", args=args, signer=signer)
    print("Whitelisting Failed as Expected")

def test_whitelist():
  # Deploy contracts
  main()

  setup_async_user("User1")

  whitelist(
    ["User1", "1", "1", "5.0", "1.0"],
    "AsyncArtAccount",
    True,
    "{1: 1}"
  )

if __name__ == '__main__':
  test_whitelist()
 