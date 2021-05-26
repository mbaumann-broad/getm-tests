import sys

print("Hello Getm!")

assert len(sys.argv) >= 3, "Usage: create_getm_manifest.py manifest_filename drs_uri [drs_uri ...]"
manifest_filename = sys.argv[1]
drs_uri_list = sys.argv[2:]
print(f"manifest_filename={manifest_filename}")
print(f"drs_uri_list={drs_uri_list}")

with open(manifest_filename, "w") as fh:
    fh.write(f"{drs_uri_list}")
