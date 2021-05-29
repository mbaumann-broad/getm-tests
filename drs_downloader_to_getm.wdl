version 1.0
workflow getm_drs_downloader {
    meta {
        description: "This workflow tests downloading DRS URIs using getm"
        tags: "DRS"
        author: "M. Baumann"
    }
    parameter_meta {
        drs_uris: "Array of DRS URIs to be downloaded"
    }
    input {
        Array[String] drs_uris
    }
    call download {
        input: drs_uris=drs_uris
    }
    output {
        File stdout = download.stdout
        File getm_manifest = download.getm_manifest
    }
}

task download {
    meta {
        description: "This task tests downloading DRS URIs using getm"
    }
    parameter_meta {
        drs_uris: "Array of DRS URIs to be downloaded"
        cpu: "runtime parameter - number of CPUs "
        memory: "runtime parameter - amount of memory to allocate in GB. Default is: 16"
        boot_disk: "runtime parameter - amount of boot disk space to allocate in GB. Default is: 50"
        disk: "runtime parameter - amount of disk space to allocate in GB. Default is: 128"
    }
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
        wget https://raw.githubusercontent.com/mbaumann-broad/getm-tests/dev/scripts/create_getm_manifest.py
        python3 ./create_getm_manifest.py ~{getm_manifest_filename} "~{sep='" "' drs_uris}"

        # Download the files in the manifest
        start_time=`date +%s`
        time getm -c -v --manifest ~{getm_manifest_filename}
        getm_exit_status=$?
        echo "Getm exit status: "$getm_exit_status
        end_time=`date +%s`

        # TODO Iterate over the manifest listing each file
        ls -lR /cromwell_root/

        # Check final disk usage after downloading
        df -h

    >>>

    output {
        File stdout = stdout()
        File getm_manifest = getm_manifest_filename
    }

    runtime {
        docker: "broadinstitute/cromwell-drs-localizer:61"
        cpu: select_first([cpu, "4"])
        memory: select_first([memory,"16"]) + " GB"
        disks: "local-disk " + select_first([disk, "128"]) + " HDD"
        bootDiskSizeGb: select_first([boot_disk,"30"])
    }
}
