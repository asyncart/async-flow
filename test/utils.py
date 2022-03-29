import json
from transaction_handler import send_transaction

def remove_leading_zeros(addr):
    while (addr[2] == '0' and 2 in range(len(addr))):
        addr = addr[:2] + addr[2+1:]
    return addr

def minimal_address(entity):
    full_addr = address(entity)
    return remove_leading_zeros(full_addr)

def address(entity):
    with open("flow.json", "r") as f:
        flow_json = json.load(f)
        if entity in flow_json['accounts']:
            return flow_json['accounts'][entity]['address']
        elif entity in flow_json['contracts']:
            # only supporting test suite on emulator for now
            emulator = flow_json['deployments']['emulator']
            for account in emulator:
                for contract in emulator[account]:
                    if entity == contract or ("name" in contract and entity == contract["name"]):
                        return flow_json['accounts'][account]["address"]
        else:
            raise Exception("Entity not an account or contract")


def transfer_flow_token(recipient, amount, signer):
    assert send_transaction("transferFlowToken", args=[["Address", address(recipient)], ["UFix64", amount]], signer=signer)
    print("Successfully transferred FlowToken")