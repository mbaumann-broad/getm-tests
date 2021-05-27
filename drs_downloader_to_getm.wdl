version 1.0
workflow getm_drs_downloader {
    input {
        Array[String] drs_uris
        Int? cpu
        Int? memory
        Int? boot_disk
        Int? disk
    }
    call download {
        input:
            drs_uris=drs_uris
    }
    output {
        File stdout = download.stdout
        File getm_manifest = download.getm_manifest
    }
    meta {
        description: "This workflow tests downloading DRS URIs using getm"
        tags: "DRS"
        author: "M. Baumann"
    }
    parameter_meta {
        drs_uris: "Array of DRS URIs to be downloaded"
        cpu: "runtime parameter - number of CPUs "
        memory: "runtime parameter - amount of memory to allocate in GB. Default is: 16"
        boot_disk: "runtime parameter - amount of boot disk space to allocate in GB. Default is: 50"
        disk: "runtime parameter - amount of disk space to allocate in GB. Default is: 128"

    }
}

task download {
    input {
        Array[String] drs_uris
        Int? cpu
        Int? memory
        Int? boot_disk
        Int? disk

        String getm_manifest_filename = "./manifest.json"
    }
    command <<<
        set -eux o pipefail

        #
        # Identify the runtime environment
        #

        # Check Linux version
        cat /etc/issue
        uname -a

        #
        # Commands that could be added to the Dockerfile
        #

        apt-get update && apt-get install -yq --no-install-recommends apt-utils git jq wget

        apt-get -yq --no-install-recommends install python3-pip \
           && python3 -m pip install --upgrade pip

        # Install getm
        pip3 install git+https://github.com/xbrianh/getm
        pip3 show getm

        #
        # DRS URI download processing
        #

        # Check available shared memory and disk usage before downloading
        df -h

        # TODO Configure shared memory appropriately, if needed.

        # Debug: Output the lists of image_files
        echo drs_uris: "~{sep='", "' drs_uris}"

        # Create a getm manifest for the DRS URIs
        wget https://raw.githubusercontent.com/mbaumann-broad/getm-tests/dev/create_getm_manifest.py
        python3 ./create_getm_manifest.py ~{getm_manifest_filename} "~{sep='" "' drs_uris}"

        # Debug: Output the contents of the getm manifest file
        cat ~{getm_manifest_filename}

        # Download the files in the manifest
        time getm -v --manifest ~{getm_manifest_filename}

        # TODO Iterate over the manifest listing each file
        ls -lR /cromwell_root/

        # Check final disk usage after downloading
        df -h

    >>>

    output {
        File stdout = stdout()
        File getm_manifest = ~{getm_manifest_filename}
    }

    runtime {
        docker: "broadinstitute/cromwell-drs-localizer:61"
        cpu: select_first([cpu, "4"])
        memory: select_first([memory,"16"]) + " GB"
        disks: "local-disk " + select_first([disk, "128"]) + " HDD"
        bootDiskSizeGb: select_first([boot_disk,"30"])
    }
}
