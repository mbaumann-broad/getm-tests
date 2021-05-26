import sys

import json

class SamAuth:
    pass

class BondProxy:
    pass

class FenceProxy:
    pass

class MockMartha:
    def resolve(self, drs_uri: str) -> dict:
        pass

class ManifestGenerator:
    def get_providers(self, drs_uri: str) -> tuple:
        drs_hostname = None
        bond_provider = None
        # TODO Implement!
        return drs_hostname, bond_provider


    def resolve_to_manifest_entry(self, drs_uri: str) -> dict:
        pass

    def resolve_all_to_manifest_json(self, drs_uris: list) -> list:
        manifest_entries = []
        for drs_uri in drs_uris:
            manifest_entry = self.resolve_to_manifest_entry(drs_uri)
            manifest_entries.append(manifest_entry)
        return manifest_entries

    def write_manifest(self, manifest_filename: str, manifest_content: dict) -> None:
        with open(manifest_filename, "w") as fh:
            fh.write(json.dumps(manifest_content, indent=4))

    def create_manifest(self, manifest_filename: str, drs_uri_list: list):
        manifest_content = self.resolve_all_to_manifest_json(drs_uri_list)
        self.write_manifest(manifest_filename, manifest_content)

# Main
print("Hello Getm!")

assert len(sys.argv) >= 3, "Usage: create_getm_manifest.py manifest_filename drs_uri [drs_uri ...]"
manifest_filename = sys.argv[1]
drs_uri_list = sys.argv[2:]
print(f"manifest_filename={manifest_filename}")
print(f"drs_uri_list={drs_uri_list}")

manifest_generator = ManifestGenerator()
manifest_generator.create_manifest(manifest_filename, drs_uri_list)

print("Done!")
