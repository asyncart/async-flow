from initialize_testing_environment import main
from transaction_handler import send_blueprints_transaction
from script_handler import send_blueprints_script_and_return_result
from event_handler import check_for_event
from utils import address
import pytest

### arg
# newPercentage: UFix64
def change_default_blueprint_secondary_fee_percentage(arg, signer, should_succeed):
  formatted_args = [["UFix64", arg]]
  
  if should_succeed:
    assert send_blueprints_transaction("changeDefaultBlueprintSecondaryFeePercentage", args=formatted_args, signer=signer)
    print("Successfully Changed the Default Blueprint Secondary Fee Percentage")
  else:
    assert not send_blueprints_transaction("changeDefaultBlueprintSecondaryFeePercentage", args=formatted_args, signer=signer)
    print("Failed to Change the Default Blueprint Secondary Fee Percentage As Expected")

@pytest.mark.core
def test_change_default_blueprint_secondary_fee_percentage():
  # Deploy contracts
  main()

  # Assert that the initial default blueprint secondary fee percentage is 7.5
  assert 7.5 == float(send_blueprints_script_and_return_result("getDefaultBlueprintSecondaryFeePercentage"))

  # Change the default blueprint secondary fee percentage
  change_default_blueprint_secondary_fee_percentage("5.0", "AsyncArtAccount", True)

  # Confirm that the new default blueprint secondary fee percentage is 5.0
  assert 5.0 == float(send_blueprints_script_and_return_result("getDefaultBlueprintSecondaryFeePercentage"))

  # Changing to a percentage higher than allowed should fail (this will fail because defaultPlatformSecondaryFeePercentage is 2.5)
  change_default_blueprint_secondary_fee_percentage("98.0", "AsyncArtAccount", False)

if __name__ == '__main__':
  test_change_default_blueprint_secondary_fee_percentage()