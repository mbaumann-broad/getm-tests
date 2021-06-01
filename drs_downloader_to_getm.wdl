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

        CURRENT_DIR=$(pwd)

        # where all non-getm downloads go (wget, gsutil, and curl)
        TMP_DL_DIR=/cromwell_root/speedtest3crdws3s

        # google project to bill for the gsutil downloads
        GOOGLE_REQUESTER_PAYS_PROJECT=platform-dev-178517

        #
        # Identify the runtime environment
        #

        # Check Linux version
        cat /etc/issue
        uname -a

        #
        # Commands that could be added to the Dockerfile
        #

        apt-get update && apt-get install -yq --no-install-recommends apt-utils git jq wget virtualenv python3.8-dev

        virtualenv -p python3.8 v38nv
        set +u
        . v38nv/bin/activate
        set -u
        # Check that we're really using python3.8
        python --version

        apt-get -yq --no-install-recommends install python3-pip
        python -m pip install --upgrade pip

        # Install getm
        python -m pip install git+https://github.com/xbrianh/getm
        python -m pip show getm

        #
        # DRS URI download processing
        #

        # Check available shared memory and disk usage before downloading
        df -h

        mkdir -p ${TMP_DL_DIR}

        # TODO Configure shared memory appropriately, if needed.

        # Create a getm manifest for the DRS URIs
        python ./create_getm_manifest.py ~{getm_manifest_filename} "~{sep='" "' drs_uris}"

        # Download the files in the manifest
        start_time=`date +%s`
        time getm -c -v --manifest ~{getm_manifest_filename}
        getm_exit_status=$?
        echo "Getm exit status: "$getm_exit_status
        end_time=`date +%s`
        total_time="$(($end_time-$start_time))"
        # Check final disk usage after downloading
        df -h

        # CLEANUP; delete to prepare for the next run
        downloaded_files=($(cat getm_manifest_filename | jq -r '.[] .filepath'))
        for downloaded_file in ${downloaded_files[@]}; do
            echo ${downloaded_file}
            ls -lha ${downloaded_file}
            rm ${downloaded_file}
        done

        # WGET DOWNLOAD of the signed URLs in the manifest
        start_time=`date +%s`
        signed_urls=($(cat getm_manifest_filename | jq -r '.[] .url'))
        for signed_url in ${signed_urls[@]}; do
            # this is going to create some crazy truncated names but it shouldn't make a difference in run times
            wget ${signed_url} -P ${TMP_DL_DIR}/
        done
        end_time=`date +%s`
        total_time="$(($end_time-$start_time))"
        # Check final disk usage after downloading
        df -h

        # CLEANUP; delete to prepare for the next run
        sudo rm -rf ${TMP_DL_DIR}/*

        # CURL DOWNLOAD of the signed URLs in the manifest
        cd ${TMP_DL_DIR}
        start_time=`date +%s`
        signed_urls=($(cat getm_manifest_filename | jq -r '.[] .url'))
        for signed_url in ${signed_urls[@]}; do
            # this is going to create some crazy truncated names but it shouldn't make a difference in run times
            curl ${signed_url} -P ${TMP_DL_DIR}/
        done
        end_time=`date +%s`
        total_time="$(($end_time-$start_time))"
        # Check final disk usage after downloading
        cd ${CURRENT_DIR}
        df -h

        # CLEANUP; delete to prepare for the next run
        sudo rm -rf ${TMP_DL_DIR}/*

        # GSUTIL DOWNLOAD of the gs:// URIs in the manifest
        start_time=`date +%s`
        google_uris=($(cat getm_manifest_filename | jq -r '.[] .gs_uri'))
        for google_uri in ${google_uris[@]}; do
            gsutil -u ${GOOGLE_REQUESTER_PAYS_PROJECT} cp ${google_uri} ${TMP_DL_DIR}/
        done
        end_time=`date +%s`
        total_time="$(($end_time-$start_time))"
        # Check final disk usage after downloading
        df -h

        # CLEANUP; final
        sudo rm -rf ${TMP_DL_DIR}
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
