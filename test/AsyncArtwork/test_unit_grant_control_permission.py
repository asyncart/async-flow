from initialize_testing_environment import main
from transaction_handler import send_async_artwork_transaction
from script_handler import send_async_artwork_script_and_return_result
from event_handler import check_for_event
from utils import address
import json
import pytest

# Test specific setup functions
from test_unit_setup_async_user import setup_async_user
from test_unit_whitelist import whitelist
from test_unit_mint_master_token import mint_master_token 
from test_unit_mint_control_token import mint_control_token

# expected args: [id, permissionedUser, grant]
def grant_control_permission(args, signer, should_succeed, expected_control_update):
  grant_args = [["UInt64", args[0]], ["Address", address(args[1])], ["Bool", args[2]]]

  if should_succeed:
    assert send_async_artwork_transaction("grantControlPermission", args=grant_args, signer=signer)
    event = f'A.{address("AsyncArtwork")[2:]}.AsyncArtwork.PermissionUpdated'
    assert check_for_event(event)
    assert expected_control_update == send_async_artwork_script_and_return_result("getControlUpdate", args=[["Address", address(args[1])]])
    print("Successfuly Updated Control Permission for User")
  else:
    assert not send_async_artwork_transaction("grantControlPermission", args=grant_args, signer=signer)
    print("Updating Control Permission Failed as Expected")

@pytest.mark.core
def test_grant_control_permission():
  # Deploy contracts
  main()

  setup_async_user("User1")
  setup_async_user("User2")
  setup_async_user("User3")

  whitelist(
    ["User1", "1", "1", "0.05", "0.01"],
    "AsyncArtAccount",
    True,
    "{1: 1}"
  )

  expected_metadata = 'A.{contract}.AsyncArtwork.NFTMetadata(id: 1, isMaster: true, uri: "<uri>", isUriLocked: false, platformFirstSalePercentage: 0.05000000, platformSecondSalePercentage: 0.01000000, tokenSoldOnce: false, numControlLevers: nil, numRemainingUpdates: nil, owner: {owner}, levers: {levers}, uniqueTokenCreators: [{uniqueTokenCreator}])'.format(contract=address("AsyncArtwork")[2:], owner=address("User1"), levers="{}", uniqueTokenCreator=address("User2"))

  mint_master_token(
    ["1", "<uri>", ["User2"], ["User2"]],
    "User1",
    True,
    "{}",
    expected_metadata=expected_metadata,
    assert_metadata=True
  )

  levers = "{{0: A.{contract}.AsyncArtwork.ControlLever(minValue: 1, maxValue: 10, currentValue: 3), 1: A.{contract}.AsyncArtwork.ControlLever(minValue: 1, maxValue: 20, currentValue: 18)}}".format(contract=address("AsyncArtwork")[2:])
  uniqueTokenCreators = f'{address("User1")}, {address("User3")}'
  expected_metadata = 'A.{contract}.AsyncArtwork.NFTMetadata(id: 2, isMaster: false, uri: "<uri>", isUriLocked: false, platformFirstSalePercentage: 0.05000000, platformSecondSalePercentage: 0.01000000, tokenSoldOnce: false, numControlLevers: nil, numRemainingUpdates: 5, owner: {owner}, levers: {levers}, uniqueTokenCreators: [{uniqueTokenCreators}])'.format(contract=address("AsyncArtwork")[2:], owner=address("User2"), levers=levers, uniqueTokenCreators=uniqueTokenCreators)

  mint_control_token(
    ["2", "<uri>", ["1", "1"], ["10", "20"], ["3", "18"], "5", ["User1", "User3"]],
    "User2",
    True,
    "{}",
    expected_metadata=expected_metadata,
    assert_metadata=True
  )

  # Check that user cannot grant permission to non-AsyncUser
  grant_control_permission(
      ["2", "User4", True],
      "User2",
      False,
      "{2: 0}"
  )

  # Check that user can grant permission to other AsyncUser
  grant_control_permission(
      ["2", "User3", True],
      "User2",
      True,
      "{2: 0}"
  )

  # Check that user can grant permission to master token owner
  grant_control_permission(
      ["2", "User1", True],
      "User2",
      True,
      "{2: 0}"
  )

  # Check that user cannot redundantly grant permission to the same user again
  grant_control_permission(
      ["2", "User3", True],
      "User2",
      False,
      "{2: 0}"
  )

  # Check that user with new permission cannot further grant permission (not NFT owner)
  grant_control_permission(
      ["2", "User1", True],
      "User3",
      False,
      "{2: 0}"
  )

  # Check that user can revoke granted permission
  grant_control_permission(
      ["2", "User3", False],
      "User2",
      True,
      "{}"
  )

if __name__ == '__main__':
  test_grant_control_permission()