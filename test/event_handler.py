import json
from subprocess import check_output, run

def check_for_n_event_occurences_over_x_blocks(num_prev_blocks, num_expected_occurences, event_name, show=False):
    event_details = check_output(["flow", "events", "get", event_name, "--last", num_prev_blocks])
    formatted_event_details = event_details.decode()
    if show:
        print(formatted_event_details)
    return formatted_event_details.count('Events Block #') == num_expected_occurences

def check_for_event(event_name, show=False):
    return check_for_n_event_occurences_over_x_blocks("200", 2, event_name, show)
