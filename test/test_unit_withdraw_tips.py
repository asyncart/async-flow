from initialize_testing_environment import main
from transaction_handler import send_transaction
from script_handler import send_script, send_script_and_return_result
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

# expected args: [recipient]

@pytest.mark.core
def withdraw_tips(args, signer, should_succeed):
  args = [["Address", address(args[0])]]
  if should_succeed:
    original_tip_balance = send_script_and_return_result("getTipBalance")
    original_recipient_balance = send_script_and_return_result("getFlowTokenVaultBalance", args=args)
    assert send_transaction("withdrawTips", args=args, signer=signer)
    assert 0.0 == float(send_script_and_return_result("getTipBalance"))
    assert float(original_recipient_balance) + float(original_tip_balance) == float(send_script_and_return_result("getFlowTokenVaultBalance", args=args))

    # FlowToken always deployed to hardcoded address on emulator
    assert check_for_event('A.0ae53cb6e3f42a79.FlowToken.TokensDeposited')
    assert check_for_event('A.0ae53cb6e3f42a79.FlowToken.TokensWithdrawn')
    print("Successfully Withdrew Tips")
  else:
    assert not send_transaction("withdrawTips", args=args, signer=signer)
    print("Withdrawing Tips Failed as Expected")

def test_whitelist():
  # Deploy contracts
  main()

  setup_async_user("User1")
  setup_async_user("User2")
  setup_async_user("User3")

  whitelist(
    ["User1", "1", "1", "5.0", "1.0"],
    "AsyncArtAccount",
    True,
    "{1: 1}"
  )

  expected_metadata = 'A.{contract}.AsyncArtwork.NFTMetadata(id: 1, isMaster: true, uri: "<uri>", isUriLocked: false, platformFirstSalePercentage: 5.00000000, platformSecondSalePercentage: 1.00000000, tokenSoldOnce: false, numControlLevers: nil, numRemainingUpdates: nil, owner: {owner}, levers: {levers}, uniqueTokenCreators: [{uniqueTokenCreator}])'.format(contract=address("AsyncArtwork")[2:], owner=address("User1"), levers="{}", uniqueTokenCreator=address("User2"))

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
  expected_metadata = 'A.{contract}.AsyncArtwork.NFTMetadata(id: 2, isMaster: false, uri: "<uri>", isUriLocked: false, platformFirstSalePercentage: 5.00000000, platformSecondSalePercentage: 1.00000000, tokenSoldOnce: false, numControlLevers: nil, numRemainingUpdates: 5, owner: {owner}, levers: {levers}, uniqueTokenCreators: [{uniqueTokenCreators}])'.format(contract=address("AsyncArtwork")[2:], owner=address("User2"), levers=levers, uniqueTokenCreators=uniqueTokenCreators)

  mint_control_token(
    ["2", "<uri>", ["1", "1"], ["10", "20"], ["3", "18"], "5", ["User1", "User3"]],
    "User2",
    True,
    "{}",
    expected_metadata=expected_metadata,
    assert_metadata=True
  )

  grant_control_permission(
      ["2", "User3", True],
      "User2",
      True,
      "{2: 0}"
  )

  levers = "{{0: A.{contract}.AsyncArtwork.ControlLever(minValue: 1, maxValue: 10, currentValue: 5), 1: A.{contract}.AsyncArtwork.ControlLever(minValue: 1, maxValue: 20, currentValue: 17)}}".format(contract=address("AsyncArtwork")[2:])
  expected_metadata = 'A.{contract}.AsyncArtwork.NFTMetadata(id: 2, isMaster: false, uri: "<uri>", isUriLocked: false, platformFirstSalePercentage: 5.00000000, platformSecondSalePercentage: 1.00000000, tokenSoldOnce: false, numControlLevers: nil, numRemainingUpdates: 4, owner: {owner}, levers: {levers}, uniqueTokenCreators: [{uniqueTokenCreators}])'.format(contract=address("AsyncArtwork")[2:], owner=address("User2"), levers=levers, uniqueTokenCreators=uniqueTokenCreators)

  transfer_flow_token("User3", "100.0", "emulator-account")

  use_control_token(
      ["2", ["0", "1"], ["5", "17"], "3.0"],
      "User3",
      True,
      expected_metadata=expected_metadata,
      assert_metadata=True
  )

  # Check that random async user can't withdraw tips to themselves
  withdraw_tips(
      ["User1"],
      "User1",
      False
  )

  # Check that random async user can't initiate a tips withdraw to AsyncAccount
  withdraw_tips(
      ["AsyncArtAccount"],
      "User1",
      False
  )

  # Check that random account can't withdraw tips
  withdraw_tips(
      ["User4"],
      "User4",
      False
  )

  # Check that the admin account can withdraw tips
  withdraw_tips(
      ["AsyncArtAccount"],
      "AsyncArtAccount",
      True
  )

if __name__ == '__main__':
  test_whitelist()
 