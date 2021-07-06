#!/usr/bin/env python3
import sys
import json
from uuid import uuid4


assert len(sys.argv) >= 3, "Usage: create_tnu_manifest.py manifest_filename drs_uri [drs_uri ...]"
manifest_filename = sys.argv[1]
drs_uri_list = sys.argv[2:]
print(f"manifest_filename={manifest_filename}")
print(f"drs_uri_list={drs_uri_list}")
manifest = [dict(drs_uri=uri, dst=f"{uuid4()}") for uri in drs_uri_list]
with open(manifest_filename, "wb") as fh:
    fh.write(json.dumps(manifest).encode("utf-8"))
