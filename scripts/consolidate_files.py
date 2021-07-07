import os
import sys
import json
from datetime import datetime

from terra_notebook_utils import table


usage = "Usage: consolidate_files.py test_name file_1 file_2 ..."
assert len(sys.argv) >= 3, usage
test_name = sys.argv[1]
file_list = sys.argv[2:]
timing_data = dict(test_name=test_name, date=datetime.utcnow().strftime("%Y-%m-%dT%H%M%S.%fZ"))
for input_file in file_list:
    if not os.path.exists(input_file):
        raise RuntimeError(f'{input_file} does not exist.  {usage}')
    with open(input_file, 'r') as fh:
        downloader_name, duration_seconds, _ = fh.read().split()
        timing_data[downloader_name] = duration_seconds

table.put_row("results", timing_data, workspace="DRS Localization Testing", workspace_namespace="anvil-stage-demo")

with open('final_timing_totals.json', 'wb') as fh:
    fh.write(json.dumps(timing_data).encode("utf-8"))
