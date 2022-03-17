# Test

### Run all

To run the entire test suite:

```
source run_tests.sh
```

(from the root directory)

### Running tests granularly

To run tests granulary, you have to first set up te testing environment. To do so, run from the root directory:

```
chmod +x setup_testing_env.sh
source setup_testing_env.sh
```

We have several test files, all of which use the pytest framework (and thus are prefixed with "test"). There are also some driver modules i.e. transaction_handler
which are used to power the tests to run using the Flow CLI and emulator.

Tests can be run as follows. It is important that all tests are run in the root directory, as all tests depend on the universal flow config file `flow.json` which must live at the root.

To Run a Single File (Verbose Logging) python3 test/<filename> for example: python3 test/test_unit_whitelist.py

To Run a Single File (As Test) pytest test/<filename> for example: pytest test/test_unit_whitelist.py

To Run the Entire Test Suite: pytest

All unit tests are "marked" as core tests. We run these against every PR, and they must pass for a PR to be merged.

- To run only "Core" tests: pytest -m core 

We also have a large integration test which doesn't necessarily cover any new cases, but tests the system against multiple simulatneous control token and master token owners, updates, tips et.c

- To run only "Non-Core" tests: pytest -v -m "not core"