from copy import deepcopy
import os
import json
from subprocess import check_output, run
import time

current_flow = {}

def init():
    global current_flow
    global existing_accounts
    global existing_contracts
    global existing_deployments
    with open("flow.json", "r") as f:
        previous_flow_json = json.load(f)
        existing_accounts = previous_flow_json['accounts']
        existing_contracts = previous_flow_json['contracts']
        existing_deployments = previous_flow_json['deployments']
    try:
        check_output('rm -rf flow.json 2>&1 > /dev/null', shell=True)
        check_output("flow init 2>&1 > /dev/null", shell=True)
    except:
        pass
    with open("flow.json", "r") as f:
        current_flow = json.load(f)

def run():
    os.system("pkill -9 flow 2>&1 > /dev/null")
    os.system('flow emulator -v --storage-limit=false --script-gas-limit=200000 2>&1 > emulator.log &')
    time.sleep(1)
    
def key_generate():
    return [X.split("\t")[1].strip() for X in check_output("flow keys generate", shell=True).decode().split("anyone!")[1].strip().split("\n")]

def create_account():
    privkey, pubkey = key_generate()
    return {'address': check_output(f"flow accounts create --key {pubkey} --signer emulator-account", shell=True).decode().split("Address")[1].split("\n")[0].strip(), 'key':privkey}

def regen_accounts():
    global current_flow
    global existing_accounts
    for account in existing_accounts:
        if account == "emulator-account":
            continue
        current_flow['accounts'][account] = create_account()

def add_deployments():
    global current_flow
    global existing_deployments
    current_flow['deployments'] = existing_deployments

def add_contracts():
    global current_flow
    global existing_contracts
    current_flow['contracts'] = existing_contracts

def write_back():
    global current_flow
    with open("flow.json", "w") as f:
        f.write(json.dumps(current_flow, indent=4))

def deploy_project():
  os.system("flow project deploy")


def main():
    init()
    run()
    regen_accounts()
    add_contracts()
    add_deployments()
    write_back()
    deploy_project()


if __name__ == '__main__':
    main()
