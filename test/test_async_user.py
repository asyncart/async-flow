from initialize_testing_environment import main
from transaction_handler import send_transaction
from script_handler import send_script, send_script_and_return_result
import pytest

@pytest.mark.core

def test_setup_async_user():
  main()
  assert send_transaction("addAsyncUser", signer="emulator-account")
  print("Created Async User")

  assert send_script("assertAsyncUser", args=[["Address", "0xf8d6e0586b0a20c7"], ["UInt64", "1"]], show=True)
  print("Validated id of created async user")

if __name__ == '__main__':
    test_setup_async_user()