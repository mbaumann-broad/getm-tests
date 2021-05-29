

def populate_manifest_sa_key(manifest_content: list, terra_google_token: str) -> list:
    """
    Populate a getm format manifest with the corresponding Gen3 service account key
    added to each entry. This may be useful for download testing of the same test input with gsutil.

    :param manifest_content: Getm manifest previously enhanced with DRS URI to facilitiate testing
    :param terra_google_token: Google token representing the current user (e.g. pet service account)
    :return: manifest with corresponding Gen3 Google service account key added to each entry
    """

    def get_bond_provider(drs_uri: str) -> str:
        if drs_uri.startswith("drs://dg.4503"):
            return "fence"
        elif drs_uri.startswith("drs://dg.ANV0"):
            return "anvil"
        elif drs_uri.startswith("drs://dg.4DFC"):
            return "dcf-fence"
        else:
            raise NotImplementedError(f"Support for this DRS URI has not yet been implemented: {drs_uri}")

    def get_service_account_key(bond_provider: str, terra_google_token: str) -> str:
        import requests
        headers = {
            'authorization': f"Bearer {terra_google_token}",
            'content-type': "application/json"
        }
        resp = requests.get(f"https://broad-bond-prod.appspot.com/api/link/v1/{bond_provider}/serviceaccount/key",
                            headers=headers)
        print(f"Request URL: {resp.request.url}")
        resp.raise_for_status()
        return resp.json().get('data')

    for manifest_entry in manifest_content:
        drs_uri = manifest_entry['drs_uri']
        bond_provider = get_bond_provider(drs_uri)
        sa_key = get_service_account_key(bond_provider, terra_google_token)
        manifest_entry['google_service_account'] = sa_key

    return manifest_content
