from initialize_testing_environment import main
from transaction_handler import send_blueprints_transaction
from script_handler import send_blueprints_script_and_return_result
from event_handler import check_for_event
from utils import address
import pytest

### arg
# newPercentage: UFix64
def change_default_platform_secondary_fee_percentage(arg, signer, should_succeed):
  formatted_args = [["UFix64", arg]]
  
  if should_succeed:
    assert send_blueprints_transaction("changeDefaultPlatformSecondaryFeePercentage", args=formatted_args, signer=signer)
    print("Successfully Changed the Default Platform Secondary Fee Percentage")
  else:
    assert not send_blueprints_transaction("changeDefaultPlatformSecondaryFeePercentage", args=formatted_args, signer=signer)
    print("Failed to Change the Default Platform Secondary Fee Percentage As Expected")

@pytest.mark.core
def test_change_default_platform_secondary_fee_percentage():
  # Deploy contracts
  main()

  # Assert that the initial default platform secondary fee percentage is 2.5
  assert 2.5 == float(send_blueprints_script_and_return_result("getDefaultPlatformSecondaryFeePercentage"))

  # Change the minter to be user2
  change_default_platform_secondary_fee_percentage("5.0", "AsyncArtAccount", True)

  # Confirm that the new default platform secondary fee percentage is 5.0
  assert 5.0 == float(send_blueprints_script_and_return_result("getDefaultPlatformSecondaryFeePercentage"))

if __name__ == '__main__':
  test_change_default_platform_secondary_fee_percentage()