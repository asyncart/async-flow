from initialize_testing_environment import main
from transaction_handler import send_blueprints_transaction
from script_handler import send_blueprints_script_and_return_result
from event_handler import check_for_event
from utils import address
import pytest

from test_unit_setup_blueprints_user import setup_blueprints_user
from test_unit_acquire_minter import acquire_minter
from test_unit_prepare_blueprint import prepare_blueprint

### Args is an array representing the following values in order (types just for info)
# newMinter: Address
def change_minter(arg, signer, should_succeed):
  formatted_args = [["Address", address(arg)]]
  
  if should_succeed:
    assert send_blueprints_transaction("changeMinter", args=formatted_args, signer=signer)
    print("Successfully Changed the Minter Address")
  else:
    assert not send_blueprints_transaction("changeMinter", args=formatted_args, signer=signer)
    print("Failed to Change the Minter Address As Expected")

@pytest.mark.core
def test_prepare_blueprint():
  # Deploy contracts
  main()
  
  # Confirm that designated minter (by default the async art account) can prepare blueprint
  prepare_blueprint(
    ["User1", "5", "10.0", "A.0ae53cb6e3f42a79.FlowToken.Vault", "metadata", "https://token-uri.com", ["User2"], "1", "2", "2"],
    "AsyncArtAccount",
    True
  )

  # User2 acquires minter resource
  acquire_minter("User2")

  # Change the minter to be user2
  change_minter("User2", "AsyncArtAccount", True)

  # Confirm that User2 can now prepare blueprints
  prepare_blueprint(
    ["User1", "5", "10.0", "A.0ae53cb6e3f42a79.FlowToken.Vault", "metadata", "https://token-uri.com", ["User2"], "1", "2", "2"],
    "User2",
    True
  )


if __name__ == '__main__':
  test_prepare_blueprint()