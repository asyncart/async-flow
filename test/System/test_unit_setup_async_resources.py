from initialize_testing_environment import main
from transaction_handler import send_transaction
from script_handler import send_script, send_script_and_return_result, send_async_artwork_script_and_return_result, send_nft_auction_script_and_return_result
from event_handler import check_for_event
from utils import address, transfer_flow_token
import pytest

def setup_async_resources(signer):
  assert send_transaction("setupAsyncResources", signer=signer)
  print(f'Successfully Setup All Async Resources for {signer}')

@pytest.mark.core
def test_setup_async_resources():
  # Deploy contracts
  main()

  # On first call to get resources User acquires all async resources, royalty switchboard, and can still send and receive custom linked currencies
  assert send_transaction("unlinkFlowTokenReceiver", signer="User1")
  assert send_transaction("unlinkFUSDReceiver", signer="User1")
  assert not send_transaction("checkAllAsyncCapabilities", signer="User1")
  setup_async_resources("User1")

  # Validate that User1 now has valid capabilities to all async resources they will need to interact with the system
  assert send_transaction("checkAllAsyncCapabilities", signer="User1")

  # Validate that User1 now has a valid royalty receiver
  assert "true" == send_script_and_return_result("isRoyaltyReceiverValid", args=[["Address", address("User1")]])

  # Validate that User1 can receive funds in the currencies it was setup with
  transfer_flow_token("User1", "100.0", "emulator-account")
  assert send_transaction("mintFUSD", args=[["UFix64", "100.0"], ["Address", address("User1")]])

  assert send_transaction("unlinkRoyaltyReceiver", signer="User1")
  setup_async_resources("User1")
  assert "true" == send_script_and_return_result("isRoyaltyReceiverValid", args=[["Address", address("User1")]])

if __name__ == '__main__':
  test_setup_async_resources()