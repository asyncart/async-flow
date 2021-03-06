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

def send_async_artwork_script(scriptname, args=None, show=False):
    scriptfile = f"cadence/scripts/AsyncArtwork/{scriptname}.cdc"
    return send_script_driver(scriptfile, args, show)

def send_nft_auction_script(scriptname, args=None, show=False):
    scriptfile = f"cadence/scripts/NFTAuction/{scriptname}.cdc"
    return send_script_driver(scriptfile, args, show)

def send_blueprints_script(scriptname, args=None, show=False):
    scriptfile = f"cadence/scripts/Blueprints/{scriptname}.cdc"
    return send_script_driver(scriptfile, args, show)

def send_script(scriptname, args=None, show=False):
    scriptfile = f"cadence/scripts/{scriptname}.cdc"
    return send_script_driver(scriptfile, args, show)

def send_script_driver(scriptfile, args, show):
    if args:
        deet = check_output(["flow", "scripts", "execute", scriptfile, "--args-json", encode_args(args)])
    else:
        deet = check_output(["flow", "scripts", "execute", scriptfile])

    if show:
        print(deet.decode())
    if "Error" in deet.decode():
        return False
    return True

def send_async_artwork_script_and_return_result(scriptname, args=None, show=False):
    scriptfile = f"cadence/scripts/AsyncArtwork/{scriptname}.cdc"
    return send_script_and_return_result_driver(scriptfile, args, show)

def send_nft_auction_script_and_return_result(scriptname, args=None, show=False):
    scriptfile = f"cadence/scripts/NFTAuction/{scriptname}.cdc"
    return send_script_and_return_result_driver(scriptfile, args, show)

def send_blueprints_script_and_return_result(scriptname, args=None, show=False):
    scriptfile = f"cadence/scripts/Blueprints/{scriptname}.cdc"
    return send_script_and_return_result_driver(scriptfile, args, show)

def send_script_and_return_result(scriptname, args=None, show=False):
    scriptfile = f"cadence/scripts/{scriptname}.cdc"
    return send_script_and_return_result_driver(scriptfile, args, show)

def send_script_and_return_result_driver(scriptfile, args, show):
    if args:
        deet = check_output(["flow", "scripts", "execute", scriptfile, "--args-json", encode_args(args)])
    else:
        deet = check_output(["flow", "scripts", "execute", scriptfile])

    if show:
        print(deet.decode())
    if "Error" in deet.decode():
        return False
    return deet.decode().strip().split("Result: ")[1]