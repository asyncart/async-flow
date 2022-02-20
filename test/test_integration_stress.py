from initialize_testing_environment import main
from transaction_handler import send_transaction
from event_handler import check_for_event
from utils import address, transfer_flow_token
import json
import pytest

# Test specific setup functions
from test_unit_setup_async_user import setup_async_user
from test_unit_whitelist import whitelist
from test_unit_mint_master_token import mint_master_token 
from test_unit_mint_control_token import mint_control_token
from test_unit_grant_control_permission import grant_control_permission
from test_unit_use_control_token import use_control_token
from test_unit_withdraw_tips import withdraw_tips
from test_unit_update_default_percentages import update_platform_default_sales_percentages

@pytest.mark.core
def test_integration():
  # Deploy contracts
  main()

  # setup user1
  setup_async_user("User1")

  # admin successfully whitelists token for user1
  whitelist(
    ["User1", "1", "1", "5.0", "1.0"],
    "AsyncArtAccount",
    True,
    "{1: 1}"
  )

  # admin tries to whitelist token for user without async collection -> fails
  whitelist(
    ["User2", "3", "2", "5.0", "1.0"],
    "AsyncArtAccount",
    False,
    "{3: 2}"
  )

  # give async collections to users 2 and 3
  setup_async_user("User2")
  setup_async_user("User3")

  # admin updates the default sales percentages
  update_platform_default_sales_percentages(["15.0", "10.0"], "AsyncArtAccount", True)

  # admin successfuly whitelists a token for user2
  whitelist(
    ["User2", "3", "2", None, None],
    "AsyncArtAccount",
    True,
    "{3: 2}"
  )

  expected_metadata = 'A.{contract}.AsyncArtwork.NFTMetadata(id: 1, isMaster: true, uri: "<uri>", isUriLocked: false, platformFirstSalePercentage: 5.00000000, platformSecondSalePercentage: 1.00000000, tokenSoldOnce: false, numControlLevers: nil, numRemainingUpdates: nil, owner: {owner}, levers: {levers}, uniqueTokenCreators: [{uniqueTokenCreator}])'.format(contract=address("AsyncArtwork")[2:], owner=address("User1"), levers="{}", uniqueTokenCreator=address("User2"))

  # User 1 mints their master token
  mint_master_token(
    ["1", "<uri>", ["User2"], ["User2"]],
    "User1",
    True,
    "{}",
    expected_metadata=expected_metadata,
    assert_metadata=True
  )

  # User2 attempts to update the levers on a control token their are allocated as part of the mint
  # above but it fails because they havent minted their control token NFT yet
  use_control_token(
      ["2", ["0", "1"], ["5", "17"], "3.0"],
      "User2",
      False
  )

  levers = "{{0: A.{contract}.AsyncArtwork.ControlLever(minValue: 1, maxValue: 10, currentValue: 3), 1: A.{contract}.AsyncArtwork.ControlLever(minValue: 1, maxValue: 20, currentValue: 18)}}".format(contract=address("AsyncArtwork")[2:])
  uniqueTokenCreators = f'{address("User1")}, {address("User3")}'
  expected_metadata = 'A.{contract}.AsyncArtwork.NFTMetadata(id: 2, isMaster: false, uri: "<uri>", isUriLocked: false, platformFirstSalePercentage: 5.00000000, platformSecondSalePercentage: 1.00000000, tokenSoldOnce: false, numControlLevers: nil, numRemainingUpdates: 2, owner: {owner}, levers: {levers}, uniqueTokenCreators: [{uniqueTokenCreators}])'.format(contract=address("AsyncArtwork")[2:], owner=address("User2"), levers=levers, uniqueTokenCreators=uniqueTokenCreators)

  # User2 mints their control token NFT
  mint_control_token(
    ["2", "<uri>", ["1", "1"], ["10", "20"], ["3", "18"], "2", ["User1", "User3"]],
    "User2",
    True,
    "{}",
    expected_metadata=expected_metadata,
    assert_metadata=True
  )

  levers = "{{0: A.{contract}.AsyncArtwork.ControlLever(minValue: 1, maxValue: 10, currentValue: 5), 1: A.{contract}.AsyncArtwork.ControlLever(minValue: 1, maxValue: 20, currentValue: 17)}}".format(contract=address("AsyncArtwork")[2:])
  expected_metadata = 'A.{contract}.AsyncArtwork.NFTMetadata(id: 2, isMaster: false, uri: "<uri>", isUriLocked: false, platformFirstSalePercentage: 5.00000000, platformSecondSalePercentage: 1.00000000, tokenSoldOnce: false, numControlLevers: nil, numRemainingUpdates: 1, owner: {owner}, levers: {levers}, uniqueTokenCreators: [{uniqueTokenCreators}])'.format(contract=address("AsyncArtwork")[2:], owner=address("User2"), levers=levers, uniqueTokenCreators=uniqueTokenCreators)

  # User2 attempts to update their recently minted control token NFT with tip
  # but it fails because they have insufficient balance
  use_control_token(
      ["2", ["0", "1"], ["5", "17"], "3.0"],
      "User2",
      False
  )

  # User2 updates their control token
  use_control_token(
      ["2", ["0", "1"], ["5", "17"], "0.0"],
      "User2",
      True,
      expected_metadata=expected_metadata,
      assert_metadata=True
  )

  expected_metadata = 'A.{contract}.AsyncArtwork.NFTMetadata(id: 3, isMaster: true, uri: "<uri>", isUriLocked: false, platformFirstSalePercentage: 15.00000000, platformSecondSalePercentage: 10.00000000, tokenSoldOnce: false, numControlLevers: nil, numRemainingUpdates: nil, owner: {owner}, levers: {levers}, uniqueTokenCreators: [])'.format(contract=address("AsyncArtwork")[2:], owner=address("User2"), levers="{}")

  # User2 mints their master token
  mint_master_token(
    ["3", "<uri>", ["User1", "User3"], []],
    "User2",
    True,
    "{}",
    expected_metadata=expected_metadata,
    assert_metadata=True
  )

  # User2 grants control permission to User3 on their master token
  # fails because you can only grant permission on master tokens
  grant_control_permission(
      ["3", "User3", True],
      "User2",
      False,
      "{2: 0}"
  )

  # User2 grants User3 permission to update their control token NFT
  grant_control_permission(
      ["2", "User3", True],
      "User2",
      True,
      "{2: 0}"
  )

  levers = "{{0: A.{contract}.AsyncArtwork.ControlLever(minValue: 1, maxValue: 10, currentValue: 3), 1: A.{contract}.AsyncArtwork.ControlLever(minValue: 1, maxValue: 20, currentValue: 18)}}".format(contract=address("AsyncArtwork")[2:])
  uniqueTokenCreators = f'{address("User1")}, {address("User3")}'
  expected_metadata = 'A.{contract}.AsyncArtwork.NFTMetadata(id: 4, isMaster: false, uri: "<uri>", isUriLocked: false, platformFirstSalePercentage: 15.00000000, platformSecondSalePercentage: 10.00000000, tokenSoldOnce: false, numControlLevers: nil, numRemainingUpdates: 5, owner: {owner}, levers: {levers}, uniqueTokenCreators: [{uniqueTokenCreators}])'.format(contract=address("AsyncArtwork")[2:], owner=address("User1"), levers=levers, uniqueTokenCreators=uniqueTokenCreators)

  # User3 mints their control NFT allocated with User2's master token
  # fails because they are allocated id 5 not 4
  mint_control_token(
    ["4", "<uri>", ["1", "1"], ["10", "20"], ["3", "18"], "5", ["User1", "User3"]],
    "User3",
    False,
    "{}"
  )

  # User1 mints their control NFT allocated with User2's master token 
  mint_control_token(
    ["4", "<uri>", ["1", "1"], ["10", "20"], ["3", "18"], "5", ["User1", "User3"]],
    "User1",
    True,
    "{}",
    expected_metadata=expected_metadata,
    assert_metadata=True
  )

  transfer_flow_token("User1", "100.0", "emulator-account")

  levers = "{{0: A.{contract}.AsyncArtwork.ControlLever(minValue: 1, maxValue: 10, currentValue: 1), 1: A.{contract}.AsyncArtwork.ControlLever(minValue: 1, maxValue: 20, currentValue: 1)}}".format(contract=address("AsyncArtwork")[2:])
  expected_metadata = 'A.{contract}.AsyncArtwork.NFTMetadata(id: 4, isMaster: false, uri: "<uri>", isUriLocked: false, platformFirstSalePercentage: 15.00000000, platformSecondSalePercentage: 10.00000000, tokenSoldOnce: false, numControlLevers: nil, numRemainingUpdates: 4, owner: {owner}, levers: {levers}, uniqueTokenCreators: [{uniqueTokenCreators}])'.format(contract=address("AsyncArtwork")[2:], owner=address("User1"), levers=levers, uniqueTokenCreators=uniqueTokenCreators)

  # User 1 attempts to update their control token with too much tip, fails
  use_control_token(
      ["4", ["0", "1"], ["1", "1"], "105.0"],
      "User1",
      False
  )

  # User 1 updates their control token
  use_control_token(
      ["4", ["0", "1"], ["1", "1"], "20.0"],
      "User1",
      True,
      expected_metadata=expected_metadata,
      assert_metadata=True
  )

  levers = "{{1: A.{contract}.AsyncArtwork.ControlLever(minValue: 1, maxValue: 20, currentValue: 18), 0: A.{contract}.AsyncArtwork.ControlLever(minValue: 1, maxValue: 10, currentValue: 3)}}".format(contract=address("AsyncArtwork")[2:])
  uniqueTokenCreators = f'{address("User1")}, {address("User3")}'
  expected_metadata = 'A.{contract}.AsyncArtwork.NFTMetadata(id: 5, isMaster: false, uri: "<uri>", isUriLocked: false, platformFirstSalePercentage: 15.00000000, platformSecondSalePercentage: 10.00000000, tokenSoldOnce: false, numControlLevers: nil, numRemainingUpdates: 5, owner: {owner}, levers: {levers}, uniqueTokenCreators: [{uniqueTokenCreators}])'.format(contract=address("AsyncArtwork")[2:], owner=address("User3"), levers=levers, uniqueTokenCreators=uniqueTokenCreators)

  # User3 mints their control NFT allocated with User2's master token 
  # Note: user3 can specify themselves as a unqiueTokenCreator
  mint_control_token(
    ["5", "<uri>", ["1", "1"], ["10", "20"], ["3", "18"], "5", ["User1", "User3"]],
    "User3",
    True,
    "{}",
    expected_metadata=expected_metadata,
    assert_metadata=True
  )

  # User2 revokes User3 permission to update their control token NFT
  grant_control_permission(
      ["2", "User3", False],
      "User2",
      True,
      "{}"
  )

  # User 3 attempts to update User2's control token but no longer has permission
  use_control_token(
      ["2", ["0", "1"], ["1", "1"], "0.0"],
      "User1",
      False
  )

  levers = "{{0: A.{contract}.AsyncArtwork.ControlLever(minValue: 1, maxValue: 10, currentValue: 5), 1: A.{contract}.AsyncArtwork.ControlLever(minValue: 1, maxValue: 20, currentValue: 17)}}".format(contract=address("AsyncArtwork")[2:])
  expected_metadata = 'A.{contract}.AsyncArtwork.NFTMetadata(id: 2, isMaster: false, uri: "<uri>", isUriLocked: false, platformFirstSalePercentage: 5.00000000, platformSecondSalePercentage: 1.00000000, tokenSoldOnce: false, numControlLevers: nil, numRemainingUpdates: 0, owner: {owner}, levers: {levers}, uniqueTokenCreators: [{uniqueTokenCreators}])'.format(contract=address("AsyncArtwork")[2:], owner=address("User2"), levers=levers, uniqueTokenCreators=uniqueTokenCreators)

  transfer_flow_token("User2", "100.0", "emulator-account")

  # User2 updates their control token
  use_control_token(
      ["2", ["0", "1"], ["5", "17"], "10.0"],
      "User2",
      True,
      expected_metadata=expected_metadata,
      assert_metadata=True
  )

  # User2 tries to update their control token but there are no more remaining updates
  use_control_token(
      ["2", ["0", "1"], ["5", "17"], "10.0"],
      "User2",
      False,
      expected_metadata=expected_metadata,
      assert_metadata=True
  )

  # Check that the admin account can withdraw tips
  withdraw_tips(
      ["AsyncArtAccount"],
      "AsyncArtAccount",
      True
  )

if __name__ == '__main__':
  test_integration()
 