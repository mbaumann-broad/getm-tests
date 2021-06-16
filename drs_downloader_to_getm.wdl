version 1.0

workflow drs {
    meta {
        description: "This workflow tests downloading DRS URIs using different downloaders (getm, curl, wget, gsutil)."
        tags: "DRS"
        author: "M. Baumann"
    }
    parameter_meta {
        drs_uris: "Array of DRS URIs to be downloaded"
    }
    input {
        Array[String] drs_uris
    }

    call create_manifest {
        input: drs_uris=drs_uris
    }
    scatter (downloader in ["getm", "curl", "wget", "gsutil", "cromwell_localizer"]) {
        call download {
            input:
                manifest=create_manifest.getm_manifest,
                downloader=downloader
        }
    }
    call consolidate_outputs {
        input: all_runs=download.timing_file
    }
    output {
        File final_timing_totals = consolidate_outputs.final_timing_totals
    }
}

task create_manifest {
    meta {
        description: "Creates a manifest mapping DRS URIs to http/gs/s3 schema appropriate for use with getm."
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

        # Identify the runtime environment; check Linux version
        cat /etc/issue
        uname -a

        # Commands that could be added to the Dockerfile
        apt-get update && apt-get install -yq --no-install-recommends apt-utils git jq wget python3.8-dev
        apt-get -yq --no-install-recommends install python3-pip
        # Check that we're really using python3.8
        python --version

        # Install getm
        python -m pip install --upgrade pip
        python -m pip install git+https://github.com/xbrianh/getm
        python -m pip show getm
        wget https://raw.githubusercontent.com/mbaumann-broad/getm-tests/dev/scripts/create_getm_manifest.py
        python ./create_getm_manifest.py ~{getm_manifest_filename} "~{sep='" "' drs_uris}"
    >>>

    output {
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

task download {
    meta {
        description: "This task tests downloading DRS URIs using the downloader of your choice (getm, curl, wget, gsutil)."
    }
    parameter_meta {
        manifest: "Manifest mapping DRS URIs to http/gs/s3 schema appropriate for use with getm."
        downloader: "The downloader to use: (getm, curl, wget, gsutil, cromwell_localizer)"
        cpu: "runtime parameter - number of CPUs"
        memory: "runtime parameter - amount of memory to allocate in GB. Default is: 16"
        boot_disk: "runtime parameter - amount of boot disk space to allocate in GB. Default is: 50"
        disk: "runtime parameter - amount of disk space to allocate in GB. Default is: 128"
    }
    input {
        File manifest
        String downloader
        Int? cpu
        Int? memory
        Int? boot_disk
        Int? disk
    }
    command <<<
        set -eux o pipefail

        CURRENT_DIR=$(pwd)

        # Where all non-getm downloads go (wget, gsutil, and curl)
        TMP_DL_DIR=/cromwell_root/speedtest3crdws3s
        mkdir -p ${TMP_DL_DIR}

        # Identify the runtime environment; Check Linux version
        cat /etc/issue
        uname -a
        apt-get update
        apt-get install -yq --no-install-recommends apt-utils git jq

        # Check available shared memory and disk usage before downloading
        # TODO Configure shared memory appropriately, if needed.
        df -h

        if [ "~{downloader}" = "getm" ]; then
            apt-get install -yq --no-install-recommends python3.8-dev
            apt-get -yq --no-install-recommends install python3-pip
            # Check that we're really using python3.8
            python --version

            # Install getm
            python -m pip install --upgrade pip
            python -m pip install git+https://github.com/xbrianh/getm
            python -m pip show getm

            # Download the files in the manifest
            start_time=`date +%s`
            time getm -c -v --manifest ~{manifest}
            getm_exit_status=$?
            echo "Getm exit status: "$getm_exit_status
            end_time=`date +%s`
            total_time="$(($end_time-$start_time))"
            # Check final disk usage after downloading
            df -h

            # verify that the downloaded filepaths exist
            downloaded_files=($(cat ~{manifest} | jq -r '.[] .filepath'))
            for downloaded_file in ${downloaded_files[@]}; do
                echo ${downloaded_file}
                ls -lha ${downloaded_file}
            done
        fi

        # WGET DOWNLOAD of the signed URLs in the manifest
        if [ "~{downloader}" = "wget" ]; then
            apt-get install -yq --no-install-recommends wget
            start_time=`date +%s`
            signed_urls=($(cat ~{manifest} | jq -r '.[] .url'))
            for signed_url in ${signed_urls[@]}; do
                # this is going to create some crazy truncated names but it shouldn't make a difference in run times
                wget ${signed_url} -P ${TMP_DL_DIR}/
            done
            end_time=`date +%s`
            total_time="$(($end_time-$start_time))"
        fi

        # CURL DOWNLOAD of the signed URLs in the manifest
        if [ "~{downloader}" = "curl" ]; then
            cd ${TMP_DL_DIR}
            start_time=`date +%s`
            signed_urls=($(cat ~{manifest} | jq -r '.[] .url'))
            for signed_url in ${signed_urls[@]}; do
                # this is going to create some crazy truncated names but it shouldn't make a difference in run times
                curl ${signed_url} -P ${TMP_DL_DIR}/
            done
            end_time=`date +%s`
            total_time="$(($end_time-$start_time))"
            cd ${CURRENT_DIR}
        fi

        # GSUTIL DOWNLOAD of the gs:// URIs in the manifest
        if [ "~{downloader}" = "gsutil" ]; then
            # Google project to bill for the gsutil downloads
            GOOGLE_REQUESTER_PAYS_PROJECT=anvil-stage-demo
            apt-get install -y apt-transport-https ca-certificates gnupg
            echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
            curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
            apt-get update -y && apt-get install -y google-cloud-sdk

            start_time=`date +%s`
            google_uris=($(cat ~{manifest} | jq -r '.[] .gs_uri'))
            for google_uri in ${google_uris[@]}; do
                gsutil -u ${GOOGLE_REQUESTER_PAYS_PROJECT} cp ${google_uri} ${TMP_DL_DIR}/
            done
            end_time=`date +%s`
            total_time="$(($end_time-$start_time))"
        fi

        # CROMWELL LOCALIZER DOWNLOAD of the drs:// URIs in the manifest
        if [ "~{downloader}" = "cromwell_localizer" ]; then
            # Google project to bill for the localizer downloads (which seems to call gsutil)
            GOOGLE_REQUESTER_PAYS_PROJECT=anvil-stage-demo
            export MARTHA_URL=https://us-central1-broad-dsde-prod.cloudfunctions.net/martha_v3
            drs_uris=($(cat ~{manifest} | jq -r '.[] .drs_uri'))
            start_time=`date +%s`
            for drs_uri in ${drs_uris[@]}; do
                java -jar /app/cromwell-drs-localizer.jar ${drs_uri} ${TMP_DL_DIR} ${GOOGLE_REQUESTER_PAYS_PROJECT}
            done
            end_time=`date +%s`
            total_time="$(($end_time-$start_time))"
        fi

        echo "~{downloader} ${total_time} seconds" > "~{downloader}.txt"
    >>>

    output {
        File timing_file = "~{downloader}.txt"
    }

    runtime {
        docker: "broadinstitute/cromwell-drs-localizer:61"
        cpu: select_first([cpu, "4"])
        memory: select_first([memory,"16"]) + " GB"
        disks: "local-disk " + select_first([disk, "128"]) + " HDD"
        bootDiskSizeGb: select_first([boot_disk,"30"])
    }
}

task consolidate_outputs {
    meta {
        description: "Takes the timing outputs from all download runs and consolidates the times into one file."
    }
    parameter_meta {
        all_runs: "Array of file paths to be consolidated"
        cpu: "runtime parameter - number of CPUs "
        memory: "runtime parameter - amount of memory to allocate in GB. Default is: 16"
        boot_disk: "runtime parameter - amount of boot disk space to allocate in GB. Default is: 50"
        disk: "runtime parameter - amount of disk space to allocate in GB. Default is: 128"
    }
    input {
        Array[File] all_runs
        Int? cpu
        Int? memory
        Int? boot_disk
        Int? disk
    }
    command <<<
        set -eux o pipefail

        # Identify the runtime environment; check Linux version
        cat /etc/issue
        uname -a

        # Commands that could be added to the Dockerfile
        apt-get update && apt-get install -yq --no-install-recommends apt-utils git jq wget python3.8-dev
        apt-get -yq --no-install-recommends install python3-pip
        # Check that we're really using python3.8
        python --version

        wget https://raw.githubusercontent.com/DailyDreaming/test/master/consolidate_files.py
        python ./consolidate_files.py "~{sep='" "' all_runs}"
    >>>

    output {
        File final_timing_totals = "final_timing_totals.txt"
    }

    runtime {
        docker: "broadinstitute/cromwell-drs-localizer:61"
        cpu: select_first([cpu, "4"])
        memory: select_first([memory,"16"]) + " GB"
        disks: "local-disk " + select_first([disk, "128"]) + " HDD"
        bootDiskSizeGb: select_first([boot_disk,"30"])
    }
}
