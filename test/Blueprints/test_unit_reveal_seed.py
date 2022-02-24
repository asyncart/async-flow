from initialize_testing_environment import main
from transaction_handler import send_blueprints_transaction
from script_handler import send_blueprints_script_and_return_result
from event_handler import check_for_event
from utils import address
import pytest

from test_unit_setup_blueprints_user import setup_blueprints_user
from test_unit_acquire_minter import acquire_minter
from test_unit_prepare_blueprint import prepare_blueprint

# args:
# blueprintID: UInt64
# randomSeed: String
def reveal_seed(args, signer, should_succeed):
  formatted_args = [["UInt64", args[0]], ["String", args[1]]]
  
  if should_succeed:
    assert send_blueprints_transaction("revealBlueprintSeed", args=formatted_args, signer=signer)
    event = f'A.{address("AsyncArtwork")[2:]}.Blueprints.BlueprintSeed'
    assert check_for_event(event)
    print("Successfully Revealed Blueprint Seal")
  else:
    assert not send_blueprints_transaction("revealBlueprintSeed", args=formatted_args, signer=signer)
    print("Failed to Reveal Blueprint Seal As Expected")

@pytest.mark.core
def test_reveal_seed():
  # Deploy contracts
  main()
  
  # Confirm that designated minter can prepare blueprint
  prepare_blueprint(
    ["User1", "5", "10.0", "A.0ae53cb6e3f42a79.FlowToken.Vault", "metadata", "https://token-uri.com", ["User2"], "1", "2", "2"],
    "AsyncArtAccount",
    True
  )

  reveal_seed(
    ["0", "example-seed"],
    "AsyncArtAccount",
    True
  )

if __name__ == '__main__':
  test_reveal_seed()