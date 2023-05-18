// Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
//
// SPDX-License-Identifier: MIT


workflow COMPRESS_MULTIQC {
    take:
        input_dir
        xz_args

    main:
        TAR_XZ(
            file("${input_dir}/multiqc/", checkIfExists: true, type: 'dir'),
            xz_args
        )

    emit:
        multiqc = TAR_XZ.out.tar
}

process TAR_XZ {
    publishDir params.publish_dir,
        enabled: !!params.publish_dir,
        mode: params.publish_dir_mode

    label 'process_short'

    input:
        path multiqc_dir
        val xz_args

    output:
        path 'multiqc.tar.xz', emit: tar

    shell:
        '''
        set -o pipefail

        if [[ '!{multiqc_dir}' != multiqc ]]; then
            ln -s '!{multiqc_dir}/' 'multiqc'
        fi

        tar -chf - multiqc/ |
            xz -T!{task.cpus} !{xz_args} > multiqc.tar.xz
        '''
}
