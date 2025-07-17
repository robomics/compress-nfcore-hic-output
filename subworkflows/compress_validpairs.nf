// Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
//
// SPDX-License-Identifier: MIT


def collect_validpairs(prefix, sample_id) {
    def files = file("${prefix}/${sample_id}*.allValidPairs",
                     type: 'file',
                     checkIfExists: true)

    def condition_id = sample_id.replaceAll(/_REP\d+$/, "")

    return tuple(sample_id, condition_id, files)
}


workflow COMPRESS_VALIDPAIRS {
    take:
        samplesheet
        input_dir
        xz_args

    main:
        Channel.fromPath(samplesheet, checkIfExists: true)
            .splitCsv(sep: ",", header: true)
            .map { it.sample }
            .unique()
            .set { sample_ids }

        sample_ids
            .map { collect_validpairs("${input_dir}/hicpro/valid_pairs", it) }
            .set { valid_pairs_input_ch }

        XZ(valid_pairs_input_ch,
           xz_args
        )

    emit:
        valid_pairs = XZ.out.xz
}

process XZ {
    label 'process_long'
    tag "$sample"

    input:
        tuple val(sample),
              val(condition),
              path(validpairs)
        val xz_args

    output:
        tuple val(sample),
              val(condition),
              path("*.xz"),
        emit: xz

    script:
        outname="${sample}.allValidPairs.xz"
        mem=task.memory.toGiga()
        """
        set -o pipefail

        trap 'rm -rf *.tmp' EXIT
        echo '$validpairs' > file_list.tmp

        xargs -a file_list.tmp cat |
        xz $xz_args \\
           -T${task.cpus} \\
           --memlimit-compress='$mem'GB \\
           > '$outname'
        """
}
