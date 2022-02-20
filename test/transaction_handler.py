import json
from subprocess import check_output

def construct_arg_list(args):
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
        elif arg[0] == 'Array':
            cur['type'] = arg[0]
            cur['value'] = construct_arg_list(arg[1])
        else:
            cur['type'] = arg[0]
            cur['value'] = arg[1]
        deet.append(cur)
    return deet

def encode_args(args):
    deet = construct_arg_list(args)
    res = json.dumps(deet)
    return res

def send_nft_auction_transaction(txname, args=None, signer='emulator-account', show=False):
    txfile = f"cadence/transactions/NFTAuction/{txname}.cdc"
    return send_transaction_driver(txfile, args, signer, show)

def send_async_artwork_transaction(txname, args=None, signer='emulator-account', show=False):
    txfile = f"cadence/transactions/AsyncArtwork/{txname}.cdc"
    return send_transaction_driver(txfile, args, signer, show)

def send_blueprints_transaction(txname, args=None, signer='emulator-account', show=False):
    txfile = f"cadence/transactions/Blueprints/{txname}.cdc"
    return send_transaction_driver(txfile, args, signer, show)

def send_transaction(txname, args=None, signer='emulator-account', show=False):
    txfile = f"cadence/transactions/{txname}.cdc"
    return send_transaction_driver(txfile, args, signer, show)

def send_transaction_driver(txfilepath, args, signer,show):
    if args:
        deet = check_output(["flow", "transactions", "send", "--args-json", encode_args(args), '--signer', signer, txfilepath])
    else:
        deet = check_output(["flow", "transactions", "send", '-l', 'debug', '--signer', signer, txfilepath])

    if show:
        print(deet.decode())
    if "Transaction Error" in deet.decode():
        return False
    return True