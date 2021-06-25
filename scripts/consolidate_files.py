import sys, os

from terra_notebook_utils import table as tnu_table


usage = "Usage: consolidate_files.py file_1 file_2 ..."
assert len(sys.argv) >= 2, usage
file_list = sys.argv[1:]
data_table_entries = {}
with open('final_timing_totals.txt', 'w') as w:
    for input_file in file_list:
        if not os.path.exists(input_file):
            raise RuntimeError(f'{input_file} does not exist.  {usage}')
        with open(input_file, 'r') as r:
            data = r.read()
            tool_name, seconds = data[:-len(' seconds')].split(' ')
            data_table_entries[tool_name] = seconds
            w.write(data + '\n')

tnu_table.put_row("getm_perf_runs", data_table_entries)
