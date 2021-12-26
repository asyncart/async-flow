from initialize_testing_environment import main
from transaction_handler import send_transaction
from script_handler import send_script, send_script_and_return_result
from event_handler import check_for_event
import pytest

@pytest.mark.core

def setup_async_user(signer):
  assert send_transaction("setupAsyncUser", signer=signer)
  print("Successfully Created Collection")

def test_setup_async_users():
  # Deploy contracts
  main()

  setup_async_user("User1")
  setup_async_user("User2")
  setup_async_user("User3")

if __name__ == '__main__':
  test_setup_async_users()