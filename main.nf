#!/usr/bin/env nextflow
// Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
//
// SPDX-License-Identifier: MIT

nextflow.enable.dsl = 2
nextflow.preview.output = 1
nextflow.enable.strict = true

def collect_files(prefix, sample_id, suffix, type = "file") {
    def files = file("${prefix}/${sample_id}*${suffix}",
                     type: type,
                     checkIfExists: true)

    def condition_id = sample_id.replaceAll(/_REP\d+$/, "")

    return tuple(sample_id, condition_id, files)
}

include { ARCHIVE_FOLDER } from './subworkflows/archive_folder.nf'
include { BAM2CRAM } from './subworkflows/compress_bwt2pairs.nf'
include { COMPRESS_VALIDPAIRS } from './subworkflows/compress_validpairs.nf'
include { COMPRESS_STATS } from './subworkflows/compress_stats.nf'


workflow {
    main:
        if (!params.nfcore_hic_outdir) log.error("Param 'nfcore_hic_outdir' is mandatory")
        if (!params.fasta) log.error("Param 'fasta' is mandatory")

        input_dir = file(params.nfcore_hic_outdir, type: 'file', checkIfExists: true)
        samplesheet = file("${input_dir}/samplesheet/samplesheet.valid.csv", type: 'file', checkIfExists: true)

        BAM2CRAM(
            samplesheet,
            input_dir,
            params.fasta,
            params.embed_ref_genome
        )

        COMPRESS_VALIDPAIRS(
            samplesheet,
            input_dir,
            params.xz_args
        )

        COMPRESS_STATS(
            samplesheet,
            input_dir,
            params.xz_args
        )

        channel.fromPath(
            "${input_dir}/*",
            checkIfExists: true,
            followLinks: true,
            glob: true,
            type: 'dir'
        )
        .filter {
            def p = it.getFileName()
            p != 'contact_maps' && p != 'hicpro'
        }
        .set { ch_folders }

        ARCHIVE_FOLDER(
            ch_folders,
            params.xz_args
        )

    publish:
        archives = ARCHIVE_FOLDER.out.tar
        cram = BAM2CRAM.out.cram
        stats = COMPRESS_STATS.out.stats
        valid_pairs = COMPRESS_VALIDPAIRS.out.valid_pairs
}

output {
    archives {
        path '.'
        mode params.publish_dir_mode
    }
    cram {
        path './alignments/'
        mode params.publish_dir_mode
    }
    stats {
        path './stats/'
        mode params.publish_dir_mode
    }
    valid_pairs {
        path './pairs/'
        mode params.publish_dir_mode
    }
}
