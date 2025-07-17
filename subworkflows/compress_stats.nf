// Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
//
// SPDX-License-Identifier: MIT


def collect_stats(prefix, sample_id) {
    def files = file("${prefix}/${sample_id}/",
                     type: 'dir',
                     checkIfExists: true)

    def condition_id = sample_id.replaceAll(/_REP\d+$/, "")

    return tuple(sample_id, condition_id, files)
}


workflow COMPRESS_STATS {
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
            .map { collect_stats("${input_dir}/hicpro/stats", it) }
            .set { stats_input_ch }

        TAR_XZ(
            stats_input_ch,
            xz_args
        )

    emit:
        stats = TAR_XZ.out.tar
}

process TAR_XZ {
    label 'process_short'
    tag "$sample"

    input:
        tuple val(sample),
              val(condition),
              path(stats_dir)
        val xz_args

    output:
        tuple val(sample),
              val(condition),
              path("*.tar.xz"), emit: tar

    script:
        outprefix="${sample}_stats"
        outname="${outprefix}.tar.xz"
        """
        set -o pipefail

        if [[ '$stats_dir' != '$outprefix' ]]; then
            ln -s '$stats_dir'/ '$outprefix'
        fi

        tar -chf - '$outprefix' |
            xz -T${task.cpus} $xz_args > '$outname'
        """
}
