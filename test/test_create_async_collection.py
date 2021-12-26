from initialize_testing_environment import main
from transaction_handler import send_transaction
from script_handler import send_script, send_script_and_return_result
from event_handler import check_for_event
import pytest

@pytest.mark.core

def setup_accounts():
  assert send_transaction("setupAsyncUser", signer="User1")
  assert send_transaction("setupAsyncUser", signer="User2")
  assert send_transaction("setupAsyncUser", signer="User3")
  print("Successfuly Created Collections")

def test_setup_async_users():
  # Deploy contracts
  main()
  setup_accounts()

if __name__ == '__main__':
    test_setup_async_users()