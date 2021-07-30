import os
import sys
import json
from datetime import datetime

from terra_notebook_utils import table


usage = "Usage: consolidate_files.py file_1 file_2 ..."
assert len(sys.argv) >= 2, usage
file_list = sys.argv[1:]
# "0_data" displays this as the first column, since data tables in the browser show columns alphabetically
timing_data = {'0_date': datetime.utcnow().strftime("%Y-%m-%dT%H%M%S.%fZ")}
for input_file in file_list:
    if not os.path.exists(input_file):
        raise RuntimeError(f'{input_file} does not exist.  {usage}')
    with open(input_file, 'r') as fh:
        try:
            downloader_name, duration_seconds, _ = fh.readline().split()
            timing_data[downloader_name] = duration_seconds
            if downloader_name in ('wget', 'curl'):
                if duration_seconds != '-1':
                    time_w_md5sum = fh.readline().split()[1]
                else:
                    time_w_md5sum = '-1'
                timing_data[f'{downloader_name}_md5sum'] = time_w_md5sum
        except:
            print(f'File contents ({input_file}): {fh.read()}')
            raise


table.put_row("results", timing_data, workspace="DRS Localization Testing", workspace_namespace="anvil-stage-demo")

with open('final_timing_totals.json', 'wb') as fh:
    fh.write(json.dumps(timing_data).encode("utf-8"))
