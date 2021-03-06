from initialize_testing_environment import main
from transaction_handler import send_async_artwork_transaction
from script_handler import send_async_artwork_script, send_async_artwork_script_and_return_result
from metadata_handler import result_equals_expected_metadata
from event_handler import check_for_event
from utils import address
import json
import pytest

# Test specific setup functions
from test_unit_setup_async_resources import setup_async_resources

# expected args: [creator, masterTokenId, layerCount, platformFirstSalePercentage, platformSecondSalePercentage]

def whitelist(args, signer, should_succeed, expected_master_mint_res=None):
  creator_address = address(args[0])
  args = [["Address", creator_address], ["UInt64", args[1]], ["UInt64", args[2]], ["UFix64?", args[3]]]
  if should_succeed:
    assert send_async_artwork_transaction("whitelist", args=args, signer=signer)
    metadata = send_async_artwork_script_and_return_result("getMasterMintReservation", args=[["Address", creator_address]])
    if expected_master_mint_res != None:
      assert result_equals_expected_metadata(metadata, expected_master_mint_res)
    # Checks that the metadata entry here is non-empty
    assert send_async_artwork_script("getMetadata", args=[args[1]])
    assert check_for_event(f'A.{address("AsyncArtwork")[2:]}.AsyncArtwork.CreatorWhitelisted')
    print("Successfuly Whitelisted Token For Creator")
  else:
    assert not send_async_artwork_transaction("whitelist", args=args, signer=signer)
    print("Whitelisting Failed as Expected")

@pytest.mark.core
def test_whitelist():
  # Deploy contracts
  main()

  setup_async_resources("User1")

  # Check successful whitelist
  whitelist(
    ["User1", "1", "1", "0.01"],
    "AsyncArtAccount",
    True,
    "{1: 1}"
  )

  # Check non-admin cannot whitelist
  whitelist(
    ["User1", "1", "1", "0.01"],
    "User1",
    False,
    "{1: 1}"
  )

  # Check cannot whitelist with invalid masterTokenId
  whitelist(
    ["User1", "2", "1", "0.01"],
    "AsyncArtAccount",
    False,
    "{1: 1}"
  )

  # Check cannot whitelist with > 500 layers
  whitelist(
    ["User1", "1", "500", "0.01"],
    "AsyncArtAccount",
    False,
    "{1: 1}"
  )

  # Check cannot whitelist with invalid sales percentages
  whitelist(
    ["User1", "1", "1", "0.01"],
    "AsyncArtAccount",
    False,
    "{1: 1}"
  )

  # Check whitelist with nil sales percentages
  whitelist(
    ["User1", "3", "1", None],
    "AsyncArtAccount",
    True,
    "{1: 1, 3: 1}"
  )

if __name__ == '__main__':
  test_whitelist()
 