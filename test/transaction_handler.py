import json
from subprocess import check_output

def encode_args(args):
    deet = []
    for arg in args:
        cur = {}
        if arg[0][-1] == '?':
            cur['type'] = "Optional"
            if arg[1] == None:
                cur['value'] = None
            else:
                cur['value'] = {}
                cur['value']['type'] = arg[0][:-1]
                cur['value']['value'] = arg[1]
        else:
            cur['type'] = arg[0]
            cur['value'] = arg[1]
        deet.append(cur)
    return json.dumps(deet)

def send_transaction(txname, args=None, signer='emulator-account', show=False):
    txfile = f"cadence/transactions/{txname}.cdc"
    if args:
        deet = check_output(["flow", "transactions", "send", "--args-json", encode_args(args), '--signer', signer, txfile])
    else:
        deet = check_output(["flow", "transactions", "send", '-l', 'debug', '--signer', signer, txfile])

    if show:
        print(deet.decode())
    if "Transaction Error" in deet.decode():
        return False
    return True