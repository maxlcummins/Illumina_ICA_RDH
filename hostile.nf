// hostile.nf
nextflow.enable.dsl = 2

VERSION = '2.2.1' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.

process HOSTILE {
    // Container image for HOSTILE

    container 'quay.io/biocontainers/hostile:1.1.0--pyhdfd78af_0'
    
    // Resource allowance
    cpus 8
    memory '8 GB'

    // Kubernetes pod annotations (if applicable)
    //pod annotation: 'scheduler.illumina.com/presetSize', value: 'fpga-medium'
    //pod annotation: 'volumes.illumina.com/scratchSize', value: '1TiB'
    
    // Publish outputs to the 'out' directory using symlinks
    publishDir 'Results/HOSTILE', mode: 'symlink'
    
    // Define inputs: sample ID and paired FASTQ files
    input:
        tuple val(sample_id), path(read1), path(read2)
        path hostile_db
    
    // Define outputs: sample ID and filtered FASTQ files
    output:
        tuple val(sample_id), path("${sample_id}_clean.R1.fastq.gz"), path("${sample_id}_clean.R2.fastq.gz"), emit: clean_reads
        path "versions.yml", emit: versions
    
    // Define the script to execute HOSTILE
    script:
    """
    export HOSTILE_CACHE_DIR=${hostile_db}

    hostile fetch --list

    echo \$HOSTILE_CACHE_DIR
    
    hostile \
        clean \
        --fastq1 ${sample_id}.R1.fastq.gz \
        --fastq2 ${sample_id}.R2.fastq.gz \
        --threads ${task.cpus} \
        --index human-t2t-hla.argos-bacteria-985_rs-viral-202401_ml-phage-202401 \
        --out-dir ${sample_id}

    mv ${sample_id}/${sample_id}.R1.clean_1.fastq.gz ${sample_id}_clean.R1.fastq.gz

    mv ${sample_id}/${sample_id}.R2.clean_2.fastq.gz ${sample_id}_clean.R2.fastq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        hostile: $VERSION

        hostile_DB: \$(hostile --version)

    END_VERSIONS
    """
}
