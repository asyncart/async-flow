from initialize_testing_environment import main
from transaction_handler import send_blueprints_transaction
from event_handler import check_for_event
import pytest

def setup_blueprints_user(signer):
  assert send_blueprints_transaction("setupBlueprintsUser", signer=signer)
  print("Successfully Created Blueprints Collection and Client")

@pytest.mark.core
def test_setup_blueprints_users():
  # Deploy contracts
  main()

  setup_blueprints_user("User1")
  setup_blueprints_user("User2")
  setup_blueprints_user("User3")

if __name__ == '__main__':
  test_setup_blueprints_users()