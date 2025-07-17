// Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
//
// SPDX-License-Identifier: MIT


def collect_bams(prefix, sample_id) {
    def files = file("${prefix}/${sample_id}*bwt2pairs.bam",
                     type: 'file',
                     checkIfExists: true)

    def condition_id = sample_id.replaceAll(/_REP\d+$/, "")

    return tuple(sample_id, condition_id, files)
}


workflow BAM2CRAM {
    take:
        samplesheet
        input_dir
        fasta
        embed_reference

    main:
        Channel.fromPath(samplesheet, checkIfExists: true)
            .splitCsv(sep: ",", header: true)
            .map { it.sample }
            .unique()
            .set { sample_ids }

        sample_ids
            .map { collect_bams("${input_dir}/hicpro/mapping", it) }
            .set { bwt2pairs_input_ch }

        SAMTOOLS(
            bwt2pairs_input_ch,
            file(fasta, type: 'file', checkIfExists: true),
            embed_reference ? 1 : 0
        )

    emit:
        cram = SAMTOOLS.out.cram
}

process SAMTOOLS {
    publishDir "${params.publish_dir}/alignments",
        enabled: !!params.publish_dir,
        mode: params.publish_dir_mode

    label 'process_long'
    tag "$sample"

    input:
        tuple val(sample),
              val(condition),
              path(bams)
        path reference_fna
        val embed_fna

    output:
        tuple val(sample),
              val(condition),
              path("*.cram"),
        emit: cram

    shell:
        mem=Math.floor(0.8 * task.memory.toMega() / task.cpus) as int
        '''
        set -o pipefail

        TMPDIR="$(mktemp -d --tmpdir="$PWD")"
        export TMPDIR

        trap "rm -rf '$TMPDIR'" EXIT
        ref="$TMPDIR/ref.fa"

        bsdcat '!{reference_fna}' > "$ref"

        samtools cat *.bam                                       |
        samtools sort -u                                         \\
                      -@!{task.cpus}                             \\
                      -m !{mem}M                                 \\
                      -T "$TMPDIR/samtools.sort"                 |
        samtools view --reference "$ref"                         \\
                      --output-fmt cram                          \\
                      --output-fmt-option archive=1              \\
                      --output-fmt-option use_lzma=1             \\
                      --output-fmt-option embed_ref=!{embed_fna} \\
                      -@!{task.cpus}                             \\
                      -o '!{sample}.bwt2pairs.cram'
        '''
}
