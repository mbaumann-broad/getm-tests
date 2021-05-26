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

        String getm_manifest = "./manifest.json"
    }
    command <<<
        set -ux

        apt-get update && apt-get install -yq --no-install-recommends apt-utils git jq wget

        apt-get -yq --no-install-recommends install python3-pip \
           && python3 -m pip install --upgrade pip

        # Diagnostic: Check Linux version
        cat /etc/issue
        uname -a

        # Diagnostic: Check available shared memory
        df -h

        # Debug: Output the lists of image_files
        echo drs_uris: "~{sep='", "' drs_uris}"

        # Install getm!
        pip3 install git+https://github.com/xbrianh/getm
        pip3 show getm

        wget https://raw.githubusercontent.com/mbaumann-broad/getm-tests/dev/create_getm_manifest.py

        python3 ./create_getm_manifest.py ~{getm_manifest} "~{sep='" "' drs_uris}"

        touch ~{getm_manifest}

        # Debug: Output the contents of the manifest file
        cat ~{getm_manifest}

        getm --manifest ~{getm_manifest}
    >>>

    output {
        File stdout = stdout()
        File getm_manifest = getm_manifest
    }

    runtime {
        # docker: "ubuntu:bionic"
        docker: "broadinstitute/cromwell-drs-localizer:61"
        cpu: select_first([cpu, "4"])
        memory: select_first([memory,"16"]) + " GB"
        disks: "local-disk " + select_first([disk, "128"]) + " HDD"
        bootDiskSizeGb: select_first([boot_disk,"30"])
    }
}
