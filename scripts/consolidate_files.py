import sys, os


usage = "Usage: consolidate_files.py file_1 file_2 ..."
assert len(sys.argv) >= 2, usage
file_list = sys.argv[1:]
with open('final_timing_totals.txt', 'w') as w:
    for input_file in file_list:
        if not os.path.exists(input_file):
            raise RuntimeError(f'{input_file} does not exist.  {usage}')
        with open(input_file, 'r') as r:
            w.write(r.read() + '\n')
