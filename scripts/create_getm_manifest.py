#!/usr/bin/env python3

import os
import sys
from subprocess import Popen, PIPE
import json

import requests


class GoogleAuth:
    def run_subprocess(self, cmd, debug=False) -> str:
        p = Popen(cmd, shell=True, stdout=PIPE, stderr=PIPE)
        stdout, stderr = p.communicate()

        stdout_str = stdout.decode("utf-8").strip()
        stderr_str = stderr.decode("utf-8").strip()

        if debug:
            print("StdOut: " + stdout_str)
            print("StdErr: " + stderr_str)

        if p.returncode != 0:
            error_text = "ERROR: unable to call command: " + cmd + "\n\n" + stdout_str + "\n\n" + stderr_str
            raise Exception(error_text)

        return stdout_str

    def get_terra_user_token(self) -> str:
        global terra_user_token
        if terra_user_token is None:
            # terra_user_token = self.run_subprocess("gcloud auth print-access-token")
            terra_user_token = self.run_subprocess("gcloud auth application-default print-access-token")
        return terra_user_token


class BondProxy:
    bond_hostname = "broad-bond-prod.appspot.com"

    def get_fence_token(self, bond_provider: str, terra_user_token: str) -> str:
        headers = {
            'authorization': f"Bearer {terra_user_token}",
            'content-type': "application/json"
        }
        resp = requests.get(f"https://{self.bond_hostname}/api/link/v1/{bond_provider}/accesstoken", headers=headers)
        print(f"Request URL: {resp.request.url}")
        resp.raise_for_status()
        return resp.json().get('token')

    def get_service_account_key(self, bond_provider: str, terra_user_token: str) -> str:
        headers = {
            'authorization': f"Bearer {terra_user_token}",
            'content-type': "application/json"
        }
        resp = requests.get(f"https://{self.bond_hostname}/api/link/v1/{bond_provider}/serviceaccount/key",
                            headers=headers)
        print(f"Request URL: {resp.request.url}")
        resp.raise_for_status()
        return resp.json().get('data')


class MockMartha:
    def __init__(self):
        self.drs_server_hostname = None
        self.drs_access_type = None
        self.bond_provider = None

    def set_service_providers(self, drs_uri: str) -> None:
        if drs_uri.startswith("drs://dg.4503"):
            self.drs_server_hostname = "gen3.biodatacatalyst.nhlbi.nih.gov"
            self.drs_access_type = "gs"
            self.bond_provider = "fence"
        elif drs_uri.startswith("drs://dg.ANV0"):
            self.drs_server_hostname = "gen3.theanvil.io"
            self.drs_access_type = "gs"
            self.bond_provider = "anvil"
        elif drs_uri.startswith("drs://dg.4DFC"):
            self.drs_server_hostname = "nci-crdc.datacommons.io"
            self.drs_access_type = "gs"
            self.bond_provider = "dcf-fence"
        else:
            raise NotImplementedError(f"Support for this DRS URI has not yet been implemented: {drs_uri}")

    def get_drs_metadata(self, drs_uri: str) -> dict:
        assert drs_uri.startswith("drs://")
        object_id = drs_uri.split(":")[-1]

        headers = {
            'content-type': "application/json"
        }

        resp = requests.get(f"https://{self.drs_server_hostname}/ga4gh/drs/v1/objects/{object_id}", headers=headers)
        print(f"Request URL: {resp.request.url}")
        resp.raise_for_status()
        return resp.json()

    def get_drs_access_id(self, drs_metadata: dict) -> str:
        for access_method in drs_metadata['access_methods']:
            if access_method['type'] == self.drs_access_type:
                return access_method['access_id']
        return None

    def get_gen3_drs_access(self, fence_user_token: str, drs_uri: str, access_id: str) -> dict:

        assert drs_uri.startswith("drs://")
        object_id = drs_uri.split(":")[-1]

        headers = {
            'authorization': f"Bearer {fence_user_token}",
            'content-type': "application/json"
        }

        resp = requests.get(f"https://{self.drs_server_hostname}/ga4gh/drs/v1/objects/{object_id}/access/{access_id}",
                            headers=headers)
        print(f"Request URL: {resp.request.url}")
        if resp.status_code != 200:
            print(resp.text)
        resp.raise_for_status()
        return resp.json()

    def get_gs_uri(self, drs_metadata: dict) -> str:
        for access_method in drs_metadata['access_methods']:
            url = access_method['access_url']['url']
            if url.startswith("gs://"):
                return url
        return None

    def get_filename(self, url: str) -> str:
        from pathlib import Path
        from urllib.parse import urlparse

        url_parts = urlparse(url)
        path_parts = Path(url_parts.path)
        return path_parts.name

    def format_drs_checksums_as_object(self, drs_checksums: list) -> dict:
        checksums_object = dict()
        for checksum in drs_checksums:
            checksums_object[checksum['type']] = checksum['checksum']
        return checksums_object

    def resolve(self, drs_uri: str) -> dict:
        self.set_service_providers(drs_uri)
        drs_metadata = self.get_drs_metadata(drs_uri)
        drs_access_id = self.get_drs_access_id(drs_metadata)
        fence_user_token = BondProxy().get_fence_token(self.bond_provider, GoogleAuth().get_terra_user_token())
        service_account_key = BondProxy().get_service_account_key(self.bond_provider, GoogleAuth().get_terra_user_token())
        drs_access_response = self.get_gen3_drs_access(fence_user_token, drs_uri, drs_access_id)
        martha_response = dict(accessUrl=drs_access_response,
                               bondProvider=self.bond_provider,
                               bucket=None,  # Not needed
                               contentType=None,  # Not needed
                               fileName=self.get_filename(drs_access_response['url']),
                               googleServiceAccount=service_account_key,
                               gsUri=self.get_gs_uri(drs_metadata),
                               hashes=self.format_drs_checksums_as_object(drs_metadata['checksums']),
                               name=drs_metadata['name'],
                               size=drs_metadata['size'],
                               timeCreated=drs_metadata['created_time'],
                               timeUpdated=drs_metadata['updated_time'])
        return martha_response


class ManifestGenerator:

    def create_filepath(self, drs_uri: str, filename: str) -> str:
        drs_uri_portion = drs_uri.replace("drs://","").replace(":","_").replace('/',"_")
        # TODO Temporary workaround for `getm` not currently creating subdirectories as needed
        subdir = f"/cromwell_root/{drs_uri_portion}"
        if not os.path.exists(subdir):
            os.mkdir(f"/cromwell_root/{drs_uri_portion}")
        # End of workaround
        return f"/cromwell_root/{drs_uri_portion}/{filename}"

    def convert_martha_response_to_manifest_entry(self, drs_uri: str, martha_response: dict) -> dict:
        manifest_entry = {
            'url': martha_response['accessUrl']['url'],
            'checksum': martha_response['hashes']['md5'],
            'checksum-algorithm': 'md5',
            'filepath': self.create_filepath(drs_uri, martha_response['fileName']),
            # Additional fields to facilitate testing
            'file_size': martha_response['size'],
            'drs_uri': drs_uri,
            'gs_uri': martha_response['gsUri']
        }
        return manifest_entry

    def resolve_to_manifest_entry(self, drs_uri: str) -> dict:
        martha = MockMartha()
        martha_response = martha.resolve(drs_uri)
        manifest_entry = self.convert_martha_response_to_manifest_entry(drs_uri, martha_response)
        # print(f"manifest_entry={json.dumps(manifest_entry, indent=4)}")
        return manifest_entry

    def resolve_all_to_manifest_json(self, drs_uris: list) -> list:
        manifest_entries = []
        for drs_uri in drs_uris:
            manifest_entry = self.resolve_to_manifest_entry(drs_uri)
            manifest_entries.append(manifest_entry)
        return manifest_entries

    def write_manifest(self, manifest_filename: str, manifest_content: list) -> None:
        with open(manifest_filename, "w") as fh:
            fh.write(json.dumps(manifest_content, indent=4))

    def print_manifest(self, manifest_content: list) -> None:
        print("Manifest Content:")
        print(json.dumps(manifest_content, indent=4))

    def create_manifest(self, manifest_filename: str, drs_uri_list: list):
        manifest_content = self.resolve_all_to_manifest_json(drs_uri_list)
        self.write_manifest(manifest_filename, manifest_content)
        self.print_manifest(manifest_content)

# Main
assert len(sys.argv) >= 3, "Usage: create_getm_manifest.py manifest_filename drs_uri [drs_uri ...]"
manifest_filename = sys.argv[1]
drs_uri_list = sys.argv[2:]
print(f"manifest_filename={manifest_filename}")
print(f"drs_uri_list={drs_uri_list}")

terra_user_token = None
manifest_generator = ManifestGenerator()
manifest_generator.create_manifest(manifest_filename, drs_uri_list)
