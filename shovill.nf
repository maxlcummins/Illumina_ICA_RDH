
// shovill.nf
nextflow.enable.dsl = 2
 
process SHOVILL {
    // Container image for SHOVILL
    container 'staphb/shovill:1.1.0-2022Dec'

    // Resource allowance
    cpus 8
    memory '16 GB'
    
    // Kubernetes pod annotations (if applicable)
    pod annotation: 'scheduler.illumina.com/presetSize', value: 'standard-medium'
    pod annotation: 'volumes.illumina.com/scratchSize', value: '100GiB'
    
    // Publish outputs to the 'out' directory using symlinks
    publishDir 'out/SHOVILL', mode: 'symlink'
    
    // Define inputs: sample ID and filtered FASTQ files from FASTP
    input:
        tuple val(sample_id), path("${sample_id}_filt_clean.R1.fastq.gz"), path("${sample_id}_filt_clean.R2.fastq.gz")
    
    // Define outputs: Assembly FASTA and log files
    output:
        tuple val(sample_id), path("${sample_id}.fasta"), emit: assembly
        path "versions.yml", emit: versions
    
    // Define the script to execute SHOVILL
    script:
    def args = task.ext.args ?: ''
    """
    shovill \\
        --R1 ${sample_id}_filt_clean.R1.fastq.gz \\
        --R2 ${sample_id}_filt_clean.R2.fastq.gz \\
        ${args} \\
        --cpus ${task.cpus} \\
        --outdir ./shovill/ \\
        --mincov 20 \\
        --minlen 200 \\
        --force

    mv shovill/contigs.fa ${sample_id}.fasta
    mv shovill/shovill.log shovill_${sample_id}.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        shovill: \$(echo \$(shovill --version 2>&1) | sed 's/^.*shovill //')
    END_VERSIONS
    """
}
