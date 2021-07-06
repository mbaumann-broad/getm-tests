"""
miniwdl plugin to inject GCP credentials into workflow tasks.
"""
import os
import tempfile
from contextlib import contextmanager

import WDL.Value


def main(cfg, logger, run_id, run_dir, task, **recv):
    # Include GCP credentials in task input
    p = os.path.join(os.path.expanduser("~"), ".config", "gcloud")
    if not os.path.exists(p) or not os.path.isfile(os.path.join(p, "application_default_credentials.json")):
        msg = ("GCP credentials are expected in `~/.config/gcloud`"
               "Please authenticate with GCP using `gcloud auth application-default login`")
        raise RuntimeError(msg)
    recv['inputs'] = recv['inputs'].bind("gcp_credentials", WDL.Value.Directory(p))
    recv = yield recv

    # inject credentials
    for host_path, container_path in recv['container'].input_path_map.items():
        if p in host_path:
            recv['command'] = _inject_sh.format(container_path=container_path) + "\n\n" + recv["command"]
            recv = yield recv
            break
    else:
        raise RuntimeError("Credentials not found input path map!")

    # do nothing with outputs
    yield recv

_inject_sh = """mkdir -p ~/.config && cp -r {container_path} ~/.config"""
