from initialize_testing_environment import main
from transaction_handler import send_blueprints_transaction
from script_handler import send_blueprints_script_and_return_result
from event_handler import check_for_event
from utils import address
import pytest

### arg
# newPercentage: UFix64
def change_default_platform_primary_fee_percentage(arg, signer, should_succeed):
  formatted_args = [["UFix64", arg]]
  
  if should_succeed:
    assert send_blueprints_transaction("changeDefaultPlatformPrimaryFeePercentage", args=formatted_args, signer=signer)
    print("Successfully Changed the Default Platform Primary Fee Percentage")
  else:
    assert not send_blueprints_transaction("changeDefaultPlatformPrimaryFeePercentage", args=formatted_args, signer=signer)
    print("Failed to Change the Default Platform Primary Fee Percentage As Expected")

@pytest.mark.core
def test_change_default_platform_primary_fee_percentage():
  # Deploy contracts
  main()

  # Assert that the initial default platform primary fee percentage is 20.0
  assert 0.2 == float(send_blueprints_script_and_return_result("getDefaultPlatformPrimaryFeePercentage"))

  # Change the minter to be user2
  change_default_platform_primary_fee_percentage("0.1", "AsyncArtAccount", True)

  # Confirm that the new default platform primary fee percentage is 10.0
  assert 0.1 == float(send_blueprints_script_and_return_result("getDefaultPlatformPrimaryFeePercentage"))

  # Changing to a percentage higher than allowed should fail
  change_default_platform_primary_fee_percentage("1.01", "AsyncArtAccount", False)

if __name__ == '__main__':
  test_change_default_platform_primary_fee_percentage()