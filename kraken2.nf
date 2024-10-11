// kraken2.nf
nextflow.enable.dsl = 2
 
process KRAKEN2 {
    // Container image for KRAKEN2
    container 'quay.io/biocontainers/kraken2:2.1.3--pl5321hdcf5f25_2'

    // Resource allowance
    cpus 8
    memory '16 GB'
    
    // Kubernetes pod annotations (if applicable)
    pod annotation: 'scheduler.illumina.com/presetSize', value: 'standard-medium'
    pod annotation: 'volumes.illumina.com/scratchSize', value: '100GiB'
    
    // Publish outputs to the 'out' directory using symlinks
    publishDir 'out/KRAKEN2', mode: 'symlink'
    
    // Define inputs: sample ID and filtered FASTQ files from FASTP
    input:
        tuple val(sample_id), path("${sample_id}_filt_clean.R1.fastq.gz"), path("${sample_id}_filt_clean.R2.fastq.gz")
        path kraken2_db
    
    // Define outputs: Assembly FASTA and log files
    output:
    tuple val(sample_id), path('*report.txt')                           , emit: report
    path "versions.yml"                                            , emit: versions
    
    // Define the script to execute KRAKEN2
    script:
    def args = task.ext.args ?: ''
    """
    kraken2 \\
        --db ${kraken2_db} \\
        --threads $task.cpus \\
        --report ${sample_id}.kraken2.report.txt \\
        --gzip-compressed \\
        $args \\
        ${sample_id}_filt_clean.R1.fastq.gz \\
        ${sample_id}_filt_clean.R2.fastq.gz \\
        

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kraken2: \$(echo \$(kraken2 --version 2>&1) | sed 's/^.*Kraken version //; s/ .*\$//')
    END_VERSIONS
    """
}
