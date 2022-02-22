from initialize_testing_environment import main
from transaction_handler import send_blueprints_transaction
from script_handler import send_blueprints_script_and_return_result
from event_handler import check_for_event
from utils import address
import pytest

# arg
# newFeeRecipient: Address
def set_async_fee_recipient(arg, signer, should_succeed):
  formatted_args = [["Address", address(arg)]]
  
  if should_succeed:
    assert send_blueprints_transaction("setAsyncFeeRecipient", args=formatted_args, signer=signer)
    print("Successfully Updated Async's Fee Recipient Address")
  else:
    assert not send_blueprints_transaction("setAsyncFeeRecipient", args=formatted_args, signer=signer)
    print("Failed to Update Async's Fee Recipient As Expected")

@pytest.mark.core
def test_set_async_fee_recipient():
  # Deploy contracts
  main()

  # Assert that the initial async fee recipient is Async Art's account
  # TODO: write a custom .equals function to compare addresses factoring in leading 0's after the 0x(000)...
  assert address("AsyncArtAccount")[3:] == send_blueprints_script_and_return_result("getAsyncFeeRecipient")[2:]

  # Change the minter to be user2
  set_async_fee_recipient("User1", "AsyncArtAccount", True)

  # Confirm that the new fee recipient is User1's account
  assert address("User1") == send_blueprints_script_and_return_result("getAsyncFeeRecipient")

if __name__ == '__main__':
  test_set_async_fee_recipient()