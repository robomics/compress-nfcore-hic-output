// Copyright (C) 2025 Roberto Rossini <roberros@uio.no>
//
// SPDX-License-Identifier: MIT


workflow ARCHIVE_FOLDER {
    take:
        input_dirs
        xz_args

    main:
        TAR_XZ(
            input_dirs,
            xz_args
        )

    emit:
        tar = TAR_XZ.out.tar
}

process TAR_XZ {
    publishDir params.publish_dir,
        enabled: !!params.publish_dir,
        mode: params.publish_dir_mode

    tag "${name}"

    label 'process_short'

    input:
        path dir
        val xz_args

    output:
        path outname, emit: tar

    shell:
        name=dir.getFileName()
        outname="${name}.tar.xz"
        '''
        set -o pipefail

        if [[ '!{dir}' != '!{name}' ]]; then
            ln -s '!{dir}/' '!{name}'
        fi

        tar -chf - '!{name}/' |
            xz -T!{task.cpus} !{xz_args} > '!{outname}'
        '''
}
