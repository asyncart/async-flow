from initialize_testing_environment import main
from transaction_handler import send_blueprints_transaction
from event_handler import check_for_event
import pytest

def acquire_minter(signer):
  assert send_blueprints_transaction("acquireMinter", signer=signer)
  print("Successfully Acquired Minter Resource")

@pytest.mark.core
def test_acquire_minter():
  # Deploy contracts
  main()

  acquire_minter("User1")

  # Still passes, just a no-op
  acquire_minter("User1")

if __name__ == '__main__':
  test_acquire_minter()